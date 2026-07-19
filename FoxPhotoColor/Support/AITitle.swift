import UIKit

/// 图像理解:把缩略图发给本地 CPA(CLIProxyAPI,Anthropic /v1/messages 兼容端点),
/// 生成中文诗意标题。任何失败(服务未启动/超时/输出不合格)都返回 nil,
/// 调用方兜底到 GPS 地名 / 默认标题。
enum AITitle {
    // ponytail: 本地开发代理,发布前换正式后端或加开关
    private static var baseURL: String {
        ProcessInfo.processInfo.environment["FPC_AI_BASE_URL"] ?? "http://127.0.0.1:8317"
    }
    private static var apiKey: String {
        ProcessInfo.processInfo.environment["FPC_AI_KEY"] ?? ""
    }
    private static var model: String {
        ProcessInfo.processInfo.environment["FPC_AI_MODEL"] ?? "claude-opus-4-8"
    }

    /// Prompt follows the user's language so English users get English titles.
    private static var prompt: String {
        if Locale.preferredLanguages.first?.hasPrefix("zh") ?? false {
            return """
            这是一张用户照片,用于生成色卡海报的标题。请给出一个 2~6 个字的中文诗意标题,\
            捕捉画面的氛围与色彩(例如:暮色小径、林间光斑、蓝调时刻)。\
            只输出标题本身,不要标点、引号或任何解释。
            """
        }
        return """
        This is a user's photo, used as the title of a color-palette poster. \
        Reply with a poetic English title of 2-4 words capturing the mood and \
        colors (e.g. Dusk Path, Forest Glow, Blue Hour). Output only the title \
        itself — no punctuation, quotes, or explanation.
        """
    }

    static func poeticTitle(for image: UIImage) async -> String? {
        guard let jpeg = downscaledJPEG(image) else { return nil }
        // CPA 池冷启动/瞬时失败重试一次即可,再失败交给调用方兜底。
        for attempt in 0..<2 {
            if let title = await requestTitle(jpeg: jpeg) { return title }
            if attempt == 0 { try? await Task.sleep(for: .seconds(1)) }
        }
        return nil
    }

    private static func requestTitle(jpeg: Data) async -> String? {
        await requestText(jpeg: jpeg, prompt: prompt, maxCharacters: 28)
    }

    /// 通用视觉请求:发图 + 提示词,清洗后返回单行文本(标题/故事共用)。
    static func requestText(jpeg: Data, prompt: String, maxCharacters: Int) async -> String? {
        guard let url = URL(string: baseURL + "/v1/messages") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 300,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64",
                                "media_type": "image/jpeg",
                                "data": jpeg.base64EncodedString()]],
                    ["type": "text", "text": prompt],
                ],
            ]],
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = payload

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch {
            if ProcessInfo.processInfo.environment["FPC_DEBUG"] == "1" {
                print("FPC_DEBUG ai request failed: \(error)")
            }
            return nil
        }
        let (data, response) = result
        if ProcessInfo.processInfo.environment["FPC_DEBUG"] == "1" {
            print("FPC_DEBUG ai status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
        else { return nil }

        // 清洗:去引号/空白,拒绝多行或超长(说明没按指令来)。
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "「」《》\"'“”"))
        guard !cleaned.isEmpty, cleaned.count <= maxCharacters, !cleaned.contains("\n") else { return nil }
        return cleaned
    }

    /// 512px 缩略 JPEG——标题理解不需要原图,省流量也省 token。
    static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 512) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: 0.6)
    }
}

extension AITitle {
    /// 背面「色彩故事」:一句话点评这张照片的色彩气质。失败返回 nil,
    /// 调用方展示占位并允许下次再试。
    static func colorStory(for image: UIImage, palette: [String]) async -> String? {
        guard let jpeg = downscaledJPEG(image) else { return nil }
        let zh = Locale.preferredLanguages.first?.hasPrefix("zh") ?? false
        let prompt = zh
            ? "这张照片提取出的主色是 \(palette.joined(separator: "、"))。请用一句 18~40 字的中文,诗意地描述这张照片的色彩气质与氛围(不要提 hex 值)。只输出这一句话,不要引号。"
            : "The photo's extracted palette is \(palette.joined(separator: ", ")). Write ONE poetic English sentence (15-30 words) about the photo's color mood. No hex codes, no quotes — output only the sentence."
        for attempt in 0..<2 {
            // 英文一句 15~30 词可到 ~190 字符,上限给足,别把合法回复清洗掉。
            if let story = await requestText(jpeg: jpeg, prompt: prompt, maxCharacters: 220) {
                return story
            }
            if attempt == 0 { try? await Task.sleep(for: .seconds(1)) }
        }
        return nil
    }
}
