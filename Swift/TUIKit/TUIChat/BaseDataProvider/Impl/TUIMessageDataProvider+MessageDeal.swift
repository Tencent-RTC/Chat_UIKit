import TIMCommon

extension TUIMessageDataProvider {
    func loadOriginMessage(from replyCellData: TUIReplyMessageCellData, callback: (() -> Void)?) {
        guard let originMsgID = replyCellData.originMsgID else {
            callback?()
            return
        }

        TUIChatDataProvider.findMessages([originMsgID]) { [weak replyCellData] succ, _, msgs in
            guard let replyCellData else { return }
            if !succ {
                replyCellData.quoteData = replyCellData.getQuoteData(originCellData: nil)
                replyCellData.originMessage = nil
                callback?()
            }

            let originMessage = msgs.first
            if originMessage == nil {
                replyCellData.quoteData = replyCellData.getQuoteData(originCellData: nil)
                callback?()
                return
            }

            let cellData = TUIMessageDataProvider.convertToCellData(from: originMessage!)
            replyCellData.originCellData = cellData

            replyCellData.updateQuoteInfo(from: cellData, originMessage: originMessage)

            if let imageData = cellData as? TUIImageMessageCellData {
                imageData.downloadImage(type: .thumb)
                replyCellData.quoteData = replyCellData.getQuoteData(originCellData: imageData)
                replyCellData.originMessage = originMessage
                callback?()
            } else if let videoData = cellData as? TUIVideoMessageCellData {
                videoData.downloadThumb()
                replyCellData.quoteData = replyCellData.getQuoteData(originCellData: videoData)
                replyCellData.originMessage = originMessage
                callback?()
            } else {
                replyCellData.quoteData = replyCellData.getQuoteData(originCellData: cellData)
                replyCellData.originMessage = originMessage
                callback?()
            }
        }
    }
}
