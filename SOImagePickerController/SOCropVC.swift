//
//  SOImageImageCropViewController.swift
//  SOImagePicker
//
//

import UIKit
import CoreGraphics

internal protocol SOCropVCDelegate {
    func imagecropvc(imagecropvc:SOCropVC, finishedcropping:UIImage)
}

internal class SOCropVC: UIViewController {
    var imgOriginal: UIImage!
    var delegate: SOCropVCDelegate?
    var cropSize: CGSize!
    var isAllowCropping = false

    private var imgCropped: UIImage!

    private var imageCropView: SOImageCropView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.automaticallyAdjustsScrollViewInsets = false
        self.navigationController?.navigationBarHidden = true

        self.setupCropView()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.imageCropView.frame = self.view.bounds
        setupBottomViewView()
    }
    
    func setupBottomViewView() {
        let viewBottom = UIView()
        viewBottom.frame = CGRectMake(0, self.view.frame.size.height-64, self.view.frame.size.width, 64)
        viewBottom.backgroundColor = UIColor.darkGrayColor()
        self.view.addSubview(viewBottom)
        
        let btnCancel = UIButton()
        btnCancel.frame = CGRectMake(10, 17, 60, 30)
        btnCancel.layer.cornerRadius = 5.0
        btnCancel.layer.masksToBounds = true
        btnCancel.setTitleColor(UIColor.blackColor(), forState: .Normal)
        btnCancel.setTitle("Cancel", forState: .Normal)
        btnCancel.backgroundColor = UIColor.whiteColor()
        btnCancel.addTarget(self, action: #selector(actionCancel), forControlEvents: .TouchUpInside)
        viewBottom.addSubview(btnCancel)
        
        let btnCrop = UIButton()
        btnCrop.frame = CGRectMake(self.view.frame.size.width-50-10, 17, 50, 30)
        btnCrop.layer.cornerRadius = 5.0
        btnCrop.layer.masksToBounds = true
        btnCrop.setTitleColor(UIColor.blackColor(), forState: .Normal)
        btnCrop.setTitle("Crop", forState: .Normal)
        btnCrop.backgroundColor = UIColor.whiteColor()
        btnCrop.addTarget(self, action: #selector(actionCrop), forControlEvents: .TouchUpInside)
        viewBottom.addSubview(btnCrop)
        
    }

    func actionCancel(sender: AnyObject?) {
        self.navigationController?.popViewControllerAnimated(true)
    }

    func actionCrop(sender: AnyObject) {
        imgCropped = self.imageCropView.croppedImage()
        self.delegate?.imagecropvc(self, finishedcropping:imgCropped)
        self.actionCancel(nil)
    }
    
    private func setupCropView() {
        self.imageCropView = SOImageCropView(frame: self.view.bounds)
        self.imageCropView.imgCrop = imgOriginal
        self.imageCropView.isAllowCropping = self.isAllowCropping
        self.imageCropView.cropSize = cropSize
        self.view.addSubview(self.imageCropView)
    }
}


internal class SOCropBorderView: UIView {
    private let kCircle: CGFloat = 20
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.backgroundColor = UIColor.clearColor()
    }
    
    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        
        CGContextSetStrokeColorWithColor(context,
                                         UIColor(red: 0.16, green: 0.25, blue: 0.75, alpha: 0.5).CGColor)
        CGContextSetLineWidth(context, 1.5)
        CGContextAddRect(context, CGRectMake(kCircle / 2, kCircle / 2,
            rect.size.width - kCircle, rect.size.height - kCircle))
        CGContextStrokePath(context)
        
        CGContextSetRGBFillColor(context, 0.16, 0.25, 0.35, 0.95)
        for handleRect in calculateAllNeededHandleRects() {
            CGContextFillEllipseInRect(context, handleRect)
        }
    }
    
    private func calculateAllNeededHandleRects() -> [CGRect] {
        
        let width = self.frame.width
        let height = self.frame.height
        
        let leftColX: CGFloat = 0
        let rightColX = width - kCircle
        let centerColX = rightColX / 2
        
        let topRowY: CGFloat = 0
        let bottomRowY = height - kCircle
        let middleRowY = bottomRowY / 2
        
        //starting with the upper left corner and then following clockwise
        let topLeft = CGRectMake(leftColX, topRowY, kCircle, kCircle)
        let topCenter = CGRectMake(centerColX, topRowY, kCircle, kCircle)
        let topRight = CGRectMake(rightColX, topRowY, kCircle, kCircle)
        let middleRight = CGRectMake(rightColX, middleRowY, kCircle, kCircle)
        let bottomRight = CGRectMake(rightColX, bottomRowY, kCircle, kCircle)
        let bottomCenter = CGRectMake(centerColX, bottomRowY, kCircle, kCircle)
        let bottomLeft = CGRectMake(leftColX, bottomRowY, kCircle, kCircle)
        let middleLeft = CGRectMake(leftColX, middleRowY, kCircle, kCircle)
        
        return [topLeft, topCenter, topRight, middleRight, bottomRight, bottomCenter, bottomLeft,
                middleLeft]
    }
}





private class ScrollView: UIScrollView {
    private override func layoutSubviews() {
        super.layoutSubviews()
        
        if let zoomView = self.delegate?.viewForZoomingInScrollView?(self) {
            let boundsSize = self.bounds.size
            var frameToCenter = zoomView.frame
            
            // center horizontally
            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }
            
            // center vertically
            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }
            
            zoomView.frame = frameToCenter
        }
    }
}

internal class SOImageCropView: UIView, UIScrollViewDelegate {
    var isAllowCropping = false
    
    private var scrollView: UIScrollView!
    private var imageView: UIImageView!
    private var cropOverlayView: SOCropOverlayView!
    private var xOffset: CGFloat!
    private var yOffset: CGFloat!
    
    private static func scaleRect(rect: CGRect, scale: CGFloat) -> CGRect {
        return CGRectMake(
            rect.origin.x * scale,
            rect.origin.y * scale,
            rect.size.width * scale,
            rect.size.height * scale)
    }
    
    var imgCrop: UIImage? {
        get {
            return self.imageView.image
        }
        set {
            self.imageView.image = newValue
        }
    }
    
    var cropSize: CGSize {
        get {
            return self.cropOverlayView.cropSize
        }
        set {
            if let view = self.cropOverlayView {
                view.cropSize = newValue
            } else {
                if self.isAllowCropping {
                    self.cropOverlayView = SOResizableCropOverlayView(frame: self.bounds,
                                                                      initialContentSize: CGSizeMake(newValue.width, newValue.height))
                } else {
                    self.cropOverlayView = SOCropOverlayView(frame: self.bounds)
                }
                self.cropOverlayView.cropSize = newValue
                self.addSubview(self.cropOverlayView)
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.userInteractionEnabled = true
        self.backgroundColor = UIColor.blackColor()
        self.scrollView = ScrollView(frame: frame)
        self.scrollView.showsHorizontalScrollIndicator = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.delegate = self
        self.scrollView.clipsToBounds = false
        self.scrollView.decelerationRate = 0
        self.scrollView.backgroundColor = UIColor.clearColor()
        self.addSubview(self.scrollView)
        
        self.imageView = UIImageView(frame: self.scrollView.frame)
        self.imageView.contentMode = .ScaleAspectFit
        self.imageView.backgroundColor = UIColor.blackColor()
        self.scrollView.addSubview(self.imageView)
        
        self.scrollView.minimumZoomScale =
            CGRectGetWidth(self.scrollView.frame) / CGRectGetHeight(self.scrollView.frame)
        self.scrollView.maximumZoomScale = 20
        self.scrollView.setZoomScale(1.0, animated: false)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        if !isAllowCropping {
            return self.scrollView
        }
        
        let resizableCropView = cropOverlayView as! SOResizableCropOverlayView
        let outerFrame = CGRectInset(resizableCropView.cropBorderView.frame, -10, -10)
        
        if CGRectContainsPoint(outerFrame, point) {
            if resizableCropView.cropBorderView.frame.size.width < 60 ||
                resizableCropView.cropBorderView.frame.size.height < 60 {
                return super.hitTest(point, withEvent: event)
            }
            
            let innerTouchFrame = CGRectInset(resizableCropView.cropBorderView.frame, 30, 30)
            if CGRectContainsPoint(innerTouchFrame, point) {
                return self.scrollView
            }
            
            let outBorderTouchFrame = CGRectInset(resizableCropView.cropBorderView.frame, -10, -10)
            if CGRectContainsPoint(outBorderTouchFrame, point) {
                return super.hitTest(point, withEvent: event)
            }
            
            return super.hitTest(point, withEvent: event)
        }
        
        return self.scrollView
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.cropSize;
        let toolbarSize = CGFloat(UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0 : 54)
        self.xOffset = floor((CGRectGetWidth(self.bounds) - size.width) * 0.5)
        self.yOffset = floor((CGRectGetHeight(self.bounds) - toolbarSize - size.height) * 0.5)
        
        let height = self.imgCrop!.size.height
        let width = self.imgCrop!.size.width
        
        var factor: CGFloat = 0
        var factoredHeight: CGFloat = 0
        var factoredWidth: CGFloat = 0
        
        if width > height {
            factor = width / size.width
            factoredWidth = size.width
            factoredHeight =  height / factor
        } else {
            factor = height / size.height
            factoredWidth = width / factor
            factoredHeight = size.height
        }
        
        self.cropOverlayView.frame = self.bounds
        self.scrollView.frame = CGRectMake(xOffset, yOffset, size.width, size.height)
        self.scrollView.contentSize = CGSizeMake(size.width, size.height)
        self.imageView.frame = CGRectMake(0, floor((size.height - factoredHeight) * 0.5),
                                          factoredWidth, factoredHeight)
    }
    
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    func croppedImage() -> UIImage {
        // Calculate rect that needs to be cropped
        var visibleRect = isAllowCropping ?
            calcVisibleRectForResizeableCropArea() : calcVisibleRectForCropArea()
        
        // transform visible rect to image orientation
        let rectTransform = orientationTransformedRectOfImage(imgCrop!)
        visibleRect = CGRectApplyAffineTransform(visibleRect, rectTransform);
        
        // finally crop image
        let imageRef = CGImageCreateWithImageInRect(imgCrop!.CGImage, visibleRect)
        let result = UIImage(CGImage: imageRef!, scale: imgCrop!.scale,
                             orientation: imgCrop!.imageOrientation)
        
        return result
    }
    
    private func calcVisibleRectForResizeableCropArea() -> CGRect {
        let resizableView = cropOverlayView as! SOResizableCropOverlayView
        
        // first of all, get the size scale by taking a look at the real image dimensions. Here it
        // doesn't matter if you take the width or the hight of the image, because it will always
        // be scaled in the exact same proportion of the real image
        var sizeScale = self.imageView.image!.size.width / self.imageView.frame.size.width
        sizeScale *= self.scrollView.zoomScale
        
        // then get the postion of the cropping rect inside the image
        var visibleRect = resizableView.contentView.convertRect(resizableView.contentView.bounds,
                                                                toView: imageView)
        visibleRect = SOImageCropView.scaleRect(visibleRect, scale: sizeScale)
        
        return visibleRect
    }
    
    private func calcVisibleRectForCropArea() -> CGRect {
        // scaled width/height in regards of real width to crop width
        let scaleWidth = imgCrop!.size.width / cropSize.width
        let scaleHeight = imgCrop!.size.height / cropSize.height
        var scale: CGFloat = 0
        
        if cropSize.width == cropSize.height {
            scale = max(scaleWidth, scaleHeight)
        } else if cropSize.width > cropSize.height {
            scale = imgCrop!.size.width < imgCrop!.size.height ?
                max(scaleWidth, scaleHeight) :
                min(scaleWidth, scaleHeight)
        } else {
            scale = imgCrop!.size.width < imgCrop!.size.height ?
                min(scaleWidth, scaleHeight) :
                max(scaleWidth, scaleHeight)
        }
        
        // extract visible rect from scrollview and scale it
        var visibleRect = scrollView.convertRect(scrollView.bounds, toView:imageView)
        visibleRect = SOImageCropView.scaleRect(visibleRect, scale: scale)
        
        return visibleRect
    }
    
    private func orientationTransformedRectOfImage(image: UIImage) -> CGAffineTransform {
        var rectTransform: CGAffineTransform!
        
        switch image.imageOrientation {
        case .Left:
            rectTransform = CGAffineTransformTranslate(
                CGAffineTransformMakeRotation(CGFloat(M_PI_2)), 0, -image.size.height)
        case .Right:
            rectTransform = CGAffineTransformTranslate(
                CGAffineTransformMakeRotation(CGFloat(-M_PI_2)),-image.size.width, 0)
        case .Down:
            rectTransform = CGAffineTransformTranslate(
                CGAffineTransformMakeRotation(CGFloat(-M_PI)),
                -image.size.width, -image.size.height)
        default:
            rectTransform = CGAffineTransformIdentity
        }
        
        return CGAffineTransformScale(rectTransform, image.scale, image.scale)
    }
}


internal class SOResizableCropOverlayView: SOCropOverlayView {
    private let kBorderWidth: CGFloat = 12
    
    var contentView: UIView!
    var cropBorderView: SOCropBorderView!
    
    private var initialContentSize = CGSize(width: 0, height: 0)
    private var resizingEnabled: Bool!
    private var anchor: CGPoint!
    private var startPoint: CGPoint!
    
    var widthValue: CGFloat!
    var heightValue: CGFloat!
    var xValue: CGFloat!
    var yValue: CGFloat!
    
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            
            let toolbarSize = CGFloat(UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0 : 54)
            let width = self.bounds.size.width
            let height = self.bounds.size.height
            
            contentView?.frame = CGRectMake((
                width - initialContentSize.width) / 2,
                                            (height - toolbarSize - initialContentSize.height) / 2,
                                            initialContentSize.width,
                                            initialContentSize.height)
            
            cropBorderView?.frame = CGRectMake(
                (width - initialContentSize.width) / 2 - kBorderWidth,
                (height - toolbarSize - initialContentSize.height) / 2 - kBorderWidth,
                initialContentSize.width + kBorderWidth * 2,
                initialContentSize.height + kBorderWidth * 2)
        }
    }
    
    init(frame: CGRect, initialContentSize: CGSize) {
        super.init(frame: frame)
        
        self.initialContentSize = initialContentSize
        self.addContentViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            let touchPoint = touch.locationInView(cropBorderView)
            
            anchor = self.calculateAnchorBorder(touchPoint)
            fillMultiplyer()
            resizingEnabled = true
            startPoint = touch.locationInView(self.superview)
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            if resizingEnabled! {
                self.resizeWithTouchPoint(touch.locationInView(self.superview))
            }
        }
    }
    
    override func drawRect(rect: CGRect) {
        //fill outer rect
        UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).set()
        UIRectFill(self.bounds)
        
        //fill inner rect
        UIColor.clearColor().set()
        UIRectFill(self.contentView.frame)
    }
    
    private func addContentViews() {
        let toolbarSize = CGFloat(UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0 : 54)
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        
        contentView = UIView(frame: CGRectMake((
            width - initialContentSize.width) / 2,
            (height - toolbarSize - initialContentSize.height) / 2,
            initialContentSize.width,
            initialContentSize.height))
        contentView.backgroundColor = UIColor.clearColor()
        self.cropSize = contentView.frame.size
        self.addSubview(contentView)
        
        cropBorderView = SOCropBorderView(frame: CGRectMake(
            (width - initialContentSize.width) / 2 - kBorderWidth,
            (height - toolbarSize - initialContentSize.height) / 2 - kBorderWidth,
            initialContentSize.width + kBorderWidth * 2,
            initialContentSize.height + kBorderWidth * 2))
        self.addSubview(cropBorderView)
    }
    
    private func calculateAnchorBorder(anchorPoint: CGPoint) -> CGPoint {
        let allHandles = getAllCurrentHandlePositions()
        var closest: CGFloat = 3000
        var anchor: CGPoint!
        
        for handlePoint in allHandles {
            // Pythagoras is watching you :-)
            let xDist = handlePoint.x - anchorPoint.x
            let yDist = handlePoint.y - anchorPoint.y
            let dist = sqrt(xDist * xDist + yDist * yDist)
            
            closest = dist < closest ? dist : closest
            anchor = closest == dist ? handlePoint : anchor
        }
        
        return anchor
    }
    
    private func getAllCurrentHandlePositions() -> [CGPoint] {
        let leftX: CGFloat = 0
        let rightX = cropBorderView.bounds.size.width
        let centerX = leftX + (rightX - leftX) / 2
        
        let topY: CGFloat = 0
        let bottomY = cropBorderView.bounds.size.height
        let middleY = topY + (bottomY - topY) / 2
        
        // starting with the upper left corner and then following the rect clockwise
        let topLeft = CGPointMake(leftX, topY)
        let topCenter = CGPointMake(centerX, topY)
        let topRight = CGPointMake(rightX, topY)
        let middleRight = CGPointMake(rightX, middleY)
        let bottomRight = CGPointMake(rightX, bottomY)
        let bottomCenter = CGPointMake(centerX, bottomY)
        let bottomLeft = CGPointMake(leftX, bottomY)
        let middleLeft = CGPointMake(leftX, middleY)
        
        return [topLeft, topCenter, topRight, middleRight, bottomRight, bottomCenter, bottomLeft,
                middleLeft]
    }
    
    private func resizeWithTouchPoint(point: CGPoint) {
        // This is the place where all the magic happends
        // prevent goint offscreen...
        let border = kBorderWidth * 2
        var pointX = point.x < border ? border : point.x
        var pointY = point.y < border ? border : point.y
        pointX = pointX > self.superview!.bounds.size.width - border ?
            self.superview!.bounds.size.width - border : pointX
        pointY = pointY > self.superview!.bounds.size.height - border ?
            self.superview!.bounds.size.height - border : pointY
        
        let heightNew = (pointY - startPoint.y) * heightValue
        let widthNew = (startPoint.x - pointX) * widthValue
        let xNew = -1 * widthNew * xValue
        let yNew = -1 * heightNew * yValue
        
        var newFrame =  CGRectMake(
            cropBorderView.frame.origin.x + xNew,
            cropBorderView.frame.origin.y + yNew,
            cropBorderView.frame.size.width + widthNew,
            cropBorderView.frame.size.height + heightNew);
        newFrame = self.preventBorderFrameFromGettingTooSmallOrTooBig(newFrame)
        self.resetFrame(to: newFrame)
        startPoint = CGPointMake(pointX, pointY)
    }
    
    private func preventBorderFrameFromGettingTooSmallOrTooBig(frame: CGRect) -> CGRect {
        let toolbarSize = CGFloat(UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0 : 54)
        var newFrame = frame
        
        if newFrame.size.width < 64 {
            newFrame.size.width = cropBorderView.frame.size.width
            newFrame.origin.x = cropBorderView.frame.origin.x
        }
        if newFrame.size.height < 64 {
            newFrame.size.height = cropBorderView.frame.size.height
            newFrame.origin.y = cropBorderView.frame.origin.y
        }
        
        if newFrame.origin.x < 0 {
            newFrame.size.width = cropBorderView.frame.size.width +
                (cropBorderView.frame.origin.x - self.superview!.bounds.origin.x)
            newFrame.origin.x = 0
        }
        
        if newFrame.origin.y < 0 {
            newFrame.size.height = cropBorderView.frame.size.height +
                (cropBorderView.frame.origin.y - self.superview!.bounds.origin.y)
            newFrame.origin.y = 0
        }
        
        if newFrame.size.width + newFrame.origin.x > self.frame.size.width {
            newFrame.size.width = self.frame.size.width - cropBorderView.frame.origin.x
        }
        
        if newFrame.size.height + newFrame.origin.y > self.frame.size.height - toolbarSize {
            newFrame.size.height = self.frame.size.height -
                cropBorderView.frame.origin.y - toolbarSize
        }
        
        return newFrame
    }
    
    private func resetFrame(to frame: CGRect) {
        cropBorderView.frame = frame
        contentView.frame = CGRectInset(frame, kBorderWidth, kBorderWidth)
        cropSize = contentView.frame.size
        self.setNeedsDisplay()
        cropBorderView.setNeedsDisplay()
    }
    
    private func fillMultiplyer() {
        heightValue = anchor.y == 0 ?
            -1 : anchor.y == cropBorderView.bounds.size.height ? 1 : 0
        widthValue = anchor.x == 0 ?
            1 : anchor.x == cropBorderView.bounds.size.width ? -1 : 0
        xValue = anchor.x == 0 ? 1 : 0
        yValue = anchor.y == 0 ? 1 : 0
    }
}





internal class SOCropOverlayView: UIView {
    
    var cropSize: CGSize!
    var toolbar: UIToolbar!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.clearColor()
        self.userInteractionEnabled = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.backgroundColor = UIColor.clearColor()
        self.userInteractionEnabled = true
    }
    
    override func drawRect(rect: CGRect) {
        
        let toolbarSize = CGFloat(UIDevice.currentDevice().userInterfaceIdiom == .Pad ? 0 : 54)
        
        let width = CGRectGetWidth(self.frame)
        let height = CGRectGetHeight(self.frame) - toolbarSize
        
        let heightSpan = floor(height / 2 - self.cropSize.height / 2)
        let widthSpan = floor(width / 2 - self.cropSize.width / 2)
        
        // fill outer rect
        UIColor(red: 0, green: 0, blue: 0, alpha: 0.5).set()
        UIRectFill(self.bounds)
        
        // fill inner border
        UIColor(red: 1, green: 1, blue: 1, alpha: 0.5).set()
        UIRectFrame(CGRectMake(widthSpan - 2, heightSpan - 2, self.cropSize.width + 4,
            self.cropSize.height + 4))
        
        // fill inner rect
        UIColor.clearColor().set()
        UIRectFill(CGRectMake(widthSpan, heightSpan, self.cropSize.width, self.cropSize.height))
    }
}
