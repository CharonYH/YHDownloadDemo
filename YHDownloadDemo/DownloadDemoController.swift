//
//  AlamofireDemoController.swift
//  StudyDemo
//
//  Created by XiaoBai on 2022/4/9.
//

import UIKit

class DownloadDemoController: UIViewController {
    
    @IBOutlet weak var currentProgressLbl: UILabel!
    
    @IBOutlet weak var progressView: UIProgressView!
    
    @IBOutlet weak var pauseDownload: UIButton!
    
    @IBAction func pauseDownload(_ sender: UIButton) {
        YHDownloadTool.shared.cancelCurrentTask()
    }
    @IBAction func startDownload(_ sender: UIButton) {
        YHDownloadTool.shared.downloadFile(with: URLString1) { downloadProgress in
            DispatchQueue.main.async {
                let progress = Float(downloadProgress.completedUnitCount) / Float(downloadProgress.totalUnitCount)
                self.progressView.progress = progress
                self.currentProgressLbl.text = "当前进度为：\(String(format: "%.3f", progress))"
                print(progress)
            }
        } to: { temporaryLocation, response in
            print("temporaryLocation = \(temporaryLocation)")
            return .init(fileURLWithPath: self.filePath + self.YourName1)
        } completionHandle: { filePath, response, error in
            print("filePath = \(filePath),error = \(error)")
        }
    }
    let URLString1 = "http://openaudio.cos.tx.xmcdn.com/group77/M08/62/A8/wKgO315_d5KTdZ6oABt5jWESM4s900.m4a"
    let YourName1 = "/YourFileNama.m4a"
    
    
    let URLString2 = "https://opensource.apple.com/tarballs/tcl/tcl-129.100.1.tar.gz"
    let YourName2 = "/YourFileNama.zip"
    
    let filePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    

}
