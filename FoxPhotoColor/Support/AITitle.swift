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
        ProcessInfo.processInfo.environment["FPC_AI_KEY"] ?? "20021001"
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
        guard let url = URL(string: baseURL + "/v1/messages") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 200,
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

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String
        else { return nil }

        return sanitized(text)
    }

    /// 模型输出清洗:去引号/空白,拒绝多行或过长的输出(说明没按指令来)。
    private static func sanitized(_ raw: String) -> String? {
        let title = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "「」《》\"'“”。.,!"))
        // 中文标题 2~6 字,英文 2~4 词——28 字符上限对两者都成立。
        guard !title.isEmpty, title.count <= 28, !title.contains("\n") else { return nil }
        return title
    }

    /// 512px 缩略 JPEG——标题理解不需要原图,省流量也省 token。
    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 512) -> Data? {
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
