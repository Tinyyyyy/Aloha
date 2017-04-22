//
//  VideoPreviewViewController.swift
//  AlohaGIF
//
//  Created by Michal Pyrka on 17/04/2017.
//  Copyright © 2017 Michal Pyrka. All rights reserved.
//

import UIKit
import AVFoundation

final class VideoPreviewViewController: UIViewController {
    
    private struct Constants {
        static let loopCountPath = "loopCount"
    }
    
    var selectedVideo: AVAsset = AVURLAsset(url: Bundle.main.url(forResource: resourceName, withExtension: "MOV")!)
    var speechArray = [SpeechModel]()
    private let player = AVQueuePlayer()
    private lazy var playerLayer: AVPlayerLayer = AVPlayerLayer(player: self.player)
    private lazy var playerItem: AVPlayerItem = AVPlayerItem(asset: self.selectedVideo)
    private lazy var playerLooper: AVPlayerLooper = AVPlayerLooper(player: self.player, templateItem: self.playerItem)
    private var observerContext = 0
    private var shouldShowOverlayText = true
    fileprivate var dynamicSubtitlesView: OverlayView!
    private var subtitlesInitialPointCenter: CGPoint!

    override func viewDidLoad() {
        super.viewDidLoad()
        playerLayer.frame = CGRect(origin: .zero, size: view.frame.size)
        view.layer.addSublayer(playerLayer)
        view.subviews.flatMap { $0 as? UIButton }.forEach {
            view.bringSubview(toFront: $0)
        }
        player.play()
        playerLooper.addObserver(self, forKeyPath: Constants.loopCountPath, options: [.new, .old], context: &observerContext)
        guard shouldShowOverlayText else { return }
        //TODO: Refactor
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
            let videoSize = self.selectedVideo.tracks(withMediaType: AVMediaTypeVideo).first?.naturalSize ?? .zero
            //For now let's say it's vertical
            let isVerticalVideo = true
            if isVerticalVideo {
                aScale = videoSize.width / self.playerLayer.videoRect.height
            } else {
                aScale = videoSize.height / self.playerLayer.videoRect.height
            }
            self.baz(frame: self.playerLayer.videoRect)
        }
    }
    
    func baz(frame: CGRect) {
            dynamicSubtitlesView = OverlayView(frame: view.frame)
            dynamicSubtitlesView.buttons = view.subviews.flatMap { $0 as? UIButton }
            dynamicSubtitlesView.frame = dynamicSubtitlesView.frame
            let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(VideoPreviewViewController.dynamicSubtitlesViewDidMove))
            dynamicSubtitlesView.addGestureRecognizer(panRecognizer)
            subtitlesInitialPointCenter = dynamicSubtitlesView.center
        DynamicSubtitlesComposer().applyDynamicSubtitles(to: DynamicSubtitlesContext.view(dynamicSubtitlesView), speechArray: speechArray, size: frame.size, delegate: self)
    }
    
    @objc private func dynamicSubtitlesViewDidMove(sender: UIPanGestureRecognizer) {
        if sender.state == .began || sender.state == .changed {
            let translation = sender.translation(in: dynamicSubtitlesView)
            aOffsetX = -(-subtitlesInitialPointCenter.x + dynamicSubtitlesView.center.x) * aScale
            aOffsetY = -(-subtitlesInitialPointCenter.y + dynamicSubtitlesView.center.y) * aScale

            sender.view!.center = CGPoint(x: sender.view!.center.x + translation.x, y: sender.view!.center.y + translation.y)
            sender.setTranslation(.zero, in: dynamicSubtitlesView)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &observerContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        if let newValue = change?[.newKey] as? Int {
            Logger.verbose("Replayed movie \(selectedVideo.description). Count: \(newValue)")
        }
    }
    
    @IBAction func exportAction(_ sender: UIButton) {
        ALLoadingView.manager.blurredBackground = true
        ALLoadingView.manager.messageText = "👽👽👽 ayy lmao"
        ALLoadingView.manager.showLoadingView(ofType: .messageWithIndicator, windowMode: .fullscreen)
        exportVideoToDynamicSubtitlesVideo()
    }
    
    //TODO: It makes analysis once again, and we already know about speech, so later is should just apply subtitles into AVAsset.
    private func exportVideoToDynamicSubtitlesVideo() {
        let speechController = SpeechController()
        speechController.createVideoWithDynamicSubtitles(from: selectedVideo, completion: { url in
            DispatchQueue.main.async {
                self.player.remove(self.playerItem)
                self.playerLooper.disableLooping()
                ALLoadingView.manager.hideLoadingView()
                self.presentVideoPreviewViewController(with: AVURLAsset(url: url))
            }
        })
    }
    
    //TODO: For debug purposes only to check whether dynamic subtitles on video have correct position like in preview
    fileprivate func presentVideoPreviewViewController(with asset: AVAsset, speechArray: [SpeechModel]? = nil) {
        let videoPreviewViewController = self.storyboard?.instantiateViewController(withIdentifier: String(describing: VideoPreviewViewController.self)) as! VideoPreviewViewController
        videoPreviewViewController.shouldShowOverlayText = false
        videoPreviewViewController.selectedVideo = asset
        if let speechArray = speechArray {
            videoPreviewViewController.speechArray = speechArray
        }
        present(videoPreviewViewController, animated: true, completion: nil)
    }
    
    @IBAction func debugAction(_ sender: UIButton) {
        player.remove(playerItem)
        playerLooper.disableLooping()
        dismiss(animated: true, completion: nil)
    }
}

extension VideoPreviewViewController: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard flag else { return }
        dynamicSubtitlesView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        DynamicSubtitlesComposer().applyDynamicSubtitles(to: DynamicSubtitlesContext.view(dynamicSubtitlesView), speechArray: speechArray, size: dynamicSubtitlesView.bounds.size, delegate: self)
    }
}
