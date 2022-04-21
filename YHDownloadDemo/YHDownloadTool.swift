//
//  YHDownloadTool.swift
//  StudyDemo
//
//  Created by XiaoBai on 2022/4/9.
//

import Foundation

//MARK: - observerable
/// 移动文件失败Notification
let YHURLSessionDownloadTaskDidFailedToMoveNotification = "YHURLSessionDownloadTaskDidFailToMoveNotification"
/// 移动文件成功Notification
let YHURLSessionDownloadTaskDidSucceedToMoveNotification = "YHURLSessionDownloadTaskDidFailToMoveNotification"

private let DefaultBackgroundIdentifer = "DefaultBackgroundIdentifer"
private var YHDownloadToolObserverContext = "YHDownloadToolObserverContext"
/// 默认文件名
private let YHDownloadDefaultHistoryPlistFileName = "YHDownloadHistory.plist"
private let YHDownloadDefaultFileName = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/\(YHDownloadDefaultHistoryPlistFileName)"

/// 将数据写入文件
/// - Parameters:
///   - dict: [String:Data]
///   - fileName: 文件名
private func Write(with dict: [String:Data]) {
    defer {
        if (dict as NSDictionary).write(toFile: YHDownloadDefaultFileName, atomically: true) {
            print("写入成功")
        }else {
            print("写入失败")
        }
    }

    if !FileManager.default.fileExists(atPath: YHDownloadDefaultFileName) {

        if FileManager.default.createFile(atPath: YHDownloadDefaultFileName, contents: nil, attributes: nil) {
            print("成功创建plist文件")
        }else {
            print("失败创建plist文件")
        }
    }


}
class YHDownloadTool: NSObject {
    
    /**
     * 完成回调
     * @param filePath 文件最终下载的位置
     * @param response URLResponse
     * @param error Error
     */
    typealias CompletionHandle = (_ filePath: URL?,
                                  _ response: URLResponse?,
                                  _ error: Error?) -> ()
    /**
     * 下载完成回调
     * @param temporaryLocation 文件在内存中的位置
     * @param response URLResponse
     * @return 文件最终的位置
     */
    typealias Destination = (_ temporaryLocation: URL,
                             _ response: URLResponse?
                             ) -> (URL)
    
    /**
     * 下载进度回调
     */
    typealias DownloadProgress = (_ downloadProgress: Progress) -> ()
    
    typealias DataTaskDidCompletionHandle = (_ session: URLSession,
                                             _ task: URLSessionTask,
                                             _ error: Error?) -> ()
    
    static let shared = YHDownloadTool()
    
    private var session: URLSession!
    
    private var completionHandle: CompletionHandle?
    private var destinationBlock: Destination?
    private var downloadProgressBlock: DownloadProgress?
    private var dataTaskDidCompletionHandle: DataTaskDidCompletionHandle?
    
    private var downloadFilePath: URL?
    private var downloadProgress: Progress!
    private var currentDownloadTask: URLSessionDownloadTask!
    
    
    private var downloadDict:[String:Data]!
    private var URLString: String!
    
    /// 是否开启后台下载（需要配置TARGETS -> capability -> Background Modes）
    var enableBackgroundDownload: Bool = false {
        didSet {
            setDataTaskDidCompletionHandle { session, task, error in
                if let error = error as NSError?,
                   let _ = error.userInfo[NSURLErrorBackgroundTaskCancelledReasonKey],let resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData] as? Data,
                   let urlString = task.currentRequest?.url?.absoluteString{
                    let dict:[String:Data] = [urlString:resumeData]
                    Write(with: dict)
                }
            }
        }
    }
    
    /// 是否开启断点续传
    var enableBreakPointDownload: Bool = false
    
    //MARK: - private method
    private func setDataTaskDidCompletionHandle(completionHandle: DataTaskDidCompletionHandle? ) {
        dataTaskDidCompletionHandle = completionHandle
    }
    
    //MARK: - init
    override init() {
        super.init()
        
        let config = URLSessionConfiguration.background(withIdentifier: DefaultBackgroundIdentifer)
        let queue = OperationQueue()
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
        
        downloadProgress = Progress(parent: nil, userInfo: nil)
        downloadProgress.addObserver(self, forKeyPath: #keyPath(Progress.fractionCompleted), options: [.new], context: &YHDownloadToolObserverContext)
    }
    
    
    /// 下载指定文件
    /// - Parameters:
    ///   - URLString: URL
    ///   - progress: DownloadProgress
    ///   - destination: Destination
    ///   - completionHandle: CompletionHandle
    /// - Returns: URLSessionDownloadTask
    @discardableResult
    func downloadFile(with URLString: String,
                      download progress: DownloadProgress?,
                      to destination: Destination?,
                      completionHandle: CompletionHandle?) -> URLSessionDownloadTask {
        self.URLString = URLString
        self.completionHandle = completionHandle
        self.destinationBlock = destination
        self.downloadProgressBlock = progress
        
        if FileManager.default.fileExists(atPath: YHDownloadDefaultFileName) {
            downloadDict = NSDictionary(contentsOfFile: YHDownloadDefaultFileName)! as? [String:Data]
        }else {
            downloadDict = [:]
        }
        
        let request = URLRequest(url: .init(string: URLString)!)
        
        if let resumeData = downloadDict[URLString] {
            print("使用旧任务")
           currentDownloadTask = session.downloadTask(withResumeData: resumeData)
        }else {
            print("使用新任务")
            currentDownloadTask = session.downloadTask(with: request)
        }
        currentDownloadTask.resume()
        return currentDownloadTask
    }
    
    /// 取消当前下载任务
    func cancelCurrentTask() {
        if currentDownloadTask.state == .running {
            currentDownloadTask.cancel {[weak self] resumeData in
                guard let WeakSelf = self else { return }
                if(WeakSelf.enableBreakPointDownload) {
                    if let resumeData = resumeData {
                        WeakSelf.downloadDict[WeakSelf.URLString] = resumeData
                        Write(with: WeakSelf.downloadDict)
                    }
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &YHDownloadToolObserverContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        if keyPath == #keyPath(Progress.fractionCompleted) {
            if let progress = object as? Progress {
                downloadProgressBlock?(progress)
            }
        }
    }

}

extension YHDownloadTool: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        completionHandle?(downloadFilePath,task.response,error)
        dataTaskDidCompletionHandle?(session,task,error)
        
        //成功下载（如果有记录则删除记录）
        if error == nil {
            if let _ = downloadDict[URLString] {
                downloadDict.removeValue(forKey: URLString)
                Write(with: downloadDict)
            }
        }
    }
    
}
extension YHDownloadTool: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let targetFilePath = destinationBlock?(location,downloadTask.response) {
            downloadFilePath = targetFilePath
            
            do {
                try FileManager.default.moveItem(at: location, to: targetFilePath)
                NotificationCenter.default.post(name: .init(rawValue: (YHURLSessionDownloadTaskDidSucceedToMoveNotification)), object: downloadTask, userInfo: nil)
            } catch {
                NotificationCenter.default.post(name: .init(rawValue: (YHURLSessionDownloadTaskDidFailedToMoveNotification)), object: downloadTask, userInfo: ["YHURLSessionDownloadTaskMoveFileFailed":error.localizedDescription])
            }
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        downloadProgress.completedUnitCount = totalBytesWritten
        downloadProgress.totalUnitCount = totalBytesExpectedToWrite
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        downloadProgress.completedUnitCount = fileOffset
        downloadProgress.totalUnitCount = expectedTotalBytes
    }
}
