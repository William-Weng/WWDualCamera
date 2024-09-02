//
//  WWDualCamera.swift
//  WWDualCamera
//
//  Created by William.Weng on 2024/7/23.
//

import UIKit
import AVFoundation

/// MARK: - 產生雙鏡頭輸出
open class WWDualCamera: NSObject {
    
    public typealias CameraSessionInput = (
        frame: CGRect,                              // 放在哪個位置上面
        deviceType: AVCaptureDevice.DeviceType,     // 鏡頭裝置類型
        position: AVCaptureDevice.Position          // 鏡頭前後位置
    )
    
    public typealias CameraSessionOutput = (
        device: AVCaptureDevice?,                   // 鏡頭裝置
        output: AVCaptureVideoDataOutput?,          // 影像輸出
        previewLayer: AVCaptureVideoPreviewLayer?,  // 預覽畫面
        error: Error?                               // 錯誤
    )
    
    public typealias MultiCamSessionCost = (
        hardware: Float,                            // 硬體壓力 (0.0 ~ 1.0)
        systemPressure: Float                       // 系統壓力 (0.0 ~ 1.0)
    )
    
    /// [是否支援多鏡頭同時動作](https://developer.apple.com/documentation/avfoundation/avcapturemulticamsession/3183002-multicamsupported)
    public var isMultiCamSupported: Bool { AVCaptureMultiCamSession.isMultiCamSupported }
    
    /// 是否正在預覽畫面
    public var isRunning: Bool { multiSession.isRunning }
    
    private var multiSession = AVCaptureMultiCamSession()
    
    private override init() {}
    
    public static let shared = WWDualCamera()
}

/// MARK: - 公開工具
public extension WWDualCamera {
    
    /// 開始執行
    /// - Returns: 有連上Session的Connection
    func start() -> [AVCaptureConnection] {
        multiSession.startRunning()
        return multiSession.connections
    }
    
    /// 關閉執行
    /// - Returns: 有連上Session的Connection
    func stop() -> [AVCaptureConnection] {
        multiSession.stopRunning()
        return multiSession.connections
    }
    
    /// 加入圖片輸出
    /// - Parameter outputs: [AVCapturePhotoOutput]
    /// - Returns: Bool
    func addPhotoOutputs(_ outputs: inout [AVCapturePhotoOutput]) -> Bool {
        
        var isSuccess = true
        outputs.forEach { isSuccess = isSuccess && multiSession._canAddOutput($0) }
        
        return isSuccess
    }
    
    /// 清除輸入裝置
    /// - Parameter inputs: [AVCaptureInput]
    /// - Returns: AVCaptureMultiCamSession所剩下的inputs
    func cleanInputs(_ inputs: [AVCaptureInput]) -> [AVCaptureInput] {
        inputs.forEach { multiSession.removeInput($0) }
        return multiSession.inputs
    }
    
    /// 清除所有輸入裝置
    /// - Returns: AVCaptureMultiCamSession所剩下的inputs
    func cleanAllInputs() -> [AVCaptureInput] {
        cleanInputs(multiSession.inputs)
    }
    
    /// 清除輸出裝置
    /// - Parameter inputs: [AVCaptureInput]
    /// - Returns: AVCaptureMultiCamSession所剩下的outputs
    func cleanOutputs(_ outputs: [AVCaptureOutput]) -> [AVCaptureOutput] {
        outputs.forEach { multiSession.removeOutput($0) }
        return multiSession.outputs
    }
    
    /// 清除所有輸出裝置
    /// - Returns: AVCaptureMultiCamSession所剩下的outputs
    func cleanAllOutputs() -> [AVCaptureOutput] {
        cleanOutputs(multiSession.outputs)
    }
    
    /// 產生輸出資訊
    /// - Parameters:
    ///   - delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    ///   - inputs: [CameraSessionInput]
    ///   - videoGravity: AVLayerVideoGravity
    /// - Returns: [CameraSessionOutput]
    func sessionOutputs(delegate: AVCaptureVideoDataOutputSampleBufferDelegate? = nil, inputs: [CameraSessionInput], videoGravity: AVLayerVideoGravity = .resizeAspectFill) -> [CameraSessionOutput] {
        let outputs = outputSetting(delegate: delegate, inputs: inputs, videoGravity: videoGravity)
        return outputs
    }
    
    /// [硬體 / 系統的用量指標](https://xiaodongxie1024.github.io/2019/04/15/20190413_iOS_VideoCaptureExplain/)
    /// - Returns: SessionCost
    func cost() -> MultiCamSessionCost {
        return multiSession._cost()
    }
}

/// MARK: - 小工具
private extension WWDualCamera {
    
    /// 影像輸出設定
    /// - Parameters:
    ///   - delegate: AVCaptureVideoDataOutputSampleBufferDelegate?
    ///   - inputs: [CameraSessionInput]
    ///   - outputs: [CameraSessionOutput]
    ///   - videoGravity: AVLayerVideoGravity
    ///   - alwaysDiscardsLateVideoFrames: [Bool](https://blog.csdn.net/github_36843038/article/details/114550865)
    /// - Returns: [CameraSessionOutput]
    func outputSetting(delegate: AVCaptureVideoDataOutputSampleBufferDelegate?, inputs: [CameraSessionInput], videoGravity: AVLayerVideoGravity, alwaysDiscardsLateVideoFrames: Bool = true) -> [CameraSessionOutput] {
        
        var outputs: [CameraSessionOutput] = []
        
        inputs.forEach { input in
            
            let _device = AVCaptureDevice.DiscoverySession(deviceTypes: [input.deviceType], mediaType: .video, position: input.position).devices.first
            var _output: CameraSessionOutput = (device: _device, output: nil, previewLayer: nil, error: nil)
            
            if let _device = _device {
                
                switch _device._captureInput() {
                case .failure(let error): outputs.append((device: nil, output: nil, previewLayer: nil, error: error))
                case .success(let _input):
                    
                    if (multiSession._canAddInput(_input)) {
                        
                        let queue = DispatchQueue(label: "\(Date().timeIntervalSince1970)")
                        let output = AVCaptureVideoDataOutput()
                        let previewLayer = multiSession._previewLayer(with: input.frame, videoGravity: videoGravity)
                        
                        output.setSampleBufferDelegate(delegate, queue: queue)
                        output.alwaysDiscardsLateVideoFrames = alwaysDiscardsLateVideoFrames
                        
                        _output.output = output
                        _output.previewLayer = previewLayer
                        
                    } else {
                        _output.error = Constant.MyError.addInput
                    }
                }
                
            } else {
                _output.error = Constant.MyError.deviceIsEmpty
            }
            
            outputs.append(_output)
        }
        
        return outputs
    }
}
