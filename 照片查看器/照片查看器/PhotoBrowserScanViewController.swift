//
//  PhotoBrowserScanViewController.swift
//  照片查看器
//
//  Created by Jiajun Zheng on 15/5/24.
//  Copyright (c) 2015年 hgProject. All rights reserved.
//

//MARK: - 属性

//MARK: - 内部方法


//MARK: - 数据源方法


//MARK: - 代理方法

import UIKit
import ZJModalKing
import SDWebImage
import SVProgressHUD
// 通知列表
// 普通dismiss通知
let PhotoBrowserStartDismissNotification = "PhotoBrowserStartDismissNotification"
let PhotoBrowserEndDismissNotification = "PhotoBrowserEndDismissNotification"
// 交互式dismiss通知
let PhotoBrowserStartInteractiveDismissNotification = "PhotoBrowserStartInteractiveDismissNotification"


private let reusedId = "photoCell"
class PhotoBrowserScanViewController: UIViewController {
    //MARK: 属性
    // 动画时长
    let AnimationDuration = 0.5 as NSTimeInterval
    /// 布局约束
    var layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
    /// 图片视图
    lazy var collectionView: UICollectionView? = {
        let cv = UICollectionView(frame: UIScreen.mainScreen().bounds, collectionViewLayout: self.layout)
        cv.backgroundColor = UIColor.clearColor()
        cv.dataSource = self
        cv.delegate = self
        // 取消指示器
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        return cv
    }()
    /// 小图数组
    var smallURLList : [NSURL]? {
        didSet {
            collectionView?.reloadData()
        }
    }
    /// 大图数组
    var largeURLList : [NSURL]?
    /// 小图开始frame
    var startFrameList : [CGRect]?
    /// 展开后frame
    var endFrameList : [CGRect]?
    /// 单张图片大小 如果没有给定该参数，单张图片显示的时候就按照layout的大小的2倍显示
    var singleImageSize : CGSize?
    /// 图片间距 默认为 10
    var imageMargin : CGFloat = 10.0
    /// 一行图片数目 默认是3
    var imageNumberInRow : Int = 3
    /// 高度约束
    var viewHeight : NSLayoutConstraint?
    /// 宽度约束
    var viewWidth : NSLayoutConstraint?
    //MARK: - 自己方法
    override func loadView() {
        view = UIView()
        view.addSubview(self.collectionView!)
        // 添加约束
        addconstraints()
    }
    override func viewDidLoad() {
        // 注册cell
        collectionView?.registerClass(PhotoCell.self, forCellWithReuseIdentifier: reusedId)
    }
    // 销毁通知
    deinit{
        removeNotification()
    }
    // 销毁注册的通知
    private func removeNotification(){
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    private func setLayout(){
        layout.itemSize = CGSizeMake(90, 90)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
    }
    // 注册通知
    private func regiserNotification(){
        // 注册开始转场动画通知
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"normalDismiss:", name: PhotoBrowserStartDismissNotification, object: nil)
        // 注册结束转场动画通知
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"interactiveDismissAnimation:", name: PhotoBrowserStartInteractiveDismissNotification, object: nil)
    }
    // 添加约束
    private func addconstraints() {
        // 开启自动布局属性
        self.collectionView?.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.setTranslatesAutoresizingMaskIntoConstraints(false)
        // 创建约束
        var cons = [AnyObject]()
        // 字典属性
        let dic = ["collectionView" : collectionView!] as [String : AnyObject]
        // 横向约束
        cons += NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[collectionView]-0-|", options: NSLayoutFormatOptions.allZeros, metrics: nil, views: dic)
        // 纵向约束
        cons += NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[collectionView]-0-|", options: NSLayoutFormatOptions.allZeros, metrics: nil, views: dic)
        // 添加约束
        // 宽高约束
        viewHeight = NSLayoutConstraint(item: view, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 0)
        viewWidth = NSLayoutConstraint(item: self.view, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute:  NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 0)
        // 宽高约束添加
        cons.append(viewHeight!)
        cons.append(viewWidth!)
        self.view.addConstraints(cons)
    }
    // 计算framelist
    private func calculateFrameLists() {
        var startFrameList = [CGRect]()
        var endFrameList = [CGRect]()
        for i in 0..<(smallURLList?.count ?? 0) {
            let indexPath = NSIndexPath(forItem: i, inSection: 0)
            let cell = collectionView!.cellForItemAtIndexPath(indexPath) as! PhotoCell
            // 计算开始frame
            let startFrame = cellStartFrameRelativeToMainScreen(cell)
            // 计算结束frame
            let endFrame = cellEndFrame(cell)
            // 储存
            startFrameList.append(startFrame)
            endFrameList.append(endFrame)
        }
        // 存储frame数组
        self.startFrameList = startFrameList
        self.endFrameList = endFrameList
    }
    // 计算view大小
    private func calculateViewSize(){
        // 还原最初布局
        setLayout()
        // 根据数组的数目
        let itemWidth = layout.itemSize.width
        let itemHeight = layout.itemSize.height
        // 无图
        if self.smallURLList == nil {
            viewHeight?.constant = 0
            viewWidth?.constant = 0
            return
        }
        // 一张图
        if self.smallURLList!.count == 1 {
            // 判断是否给定大小
            if singleImageSize == nil {
                let size = CGSizeMake(itemWidth * 2, itemHeight * 2)
                viewHeight?.constant = size.height
                viewWidth?.constant = size.width
                layout.itemSize = size
                return
            }
            // 有初始大小
            viewHeight?.constant = singleImageSize!.height
            viewWidth?.constant = singleImageSize!.width
            return
        }
        // 2张图片
        if self.smallURLList!.count == 2 {
            viewHeight?.constant = itemHeight
            viewWidth?.constant = itemWidth * 2 + imageMargin
            return
        }
        // 特殊张数图片
        if self.smallURLList!.count == ((imageNumberInRow - 1) * 2) {
            let number = CGFloat(imageNumberInRow - 1)
            let width = itemWidth * number + imageMargin
            let height = itemHeight * number + imageMargin
            viewHeight?.constant = height
            viewWidth?.constant = width
            return
        }
        //  其他图片数量
        let count = self.smallURLList!.count
        let row = CGFloat(count / imageNumberInRow + 1)
        let width = itemWidth * CGFloat(imageNumberInRow) +  imageMargin * CGFloat(imageNumberInRow - 1)
        let height = itemHeight * row + imageMargin * (row - 1)
        viewHeight?.constant = height
        viewWidth?.constant = width
    }
    // 坐标转换
    private func cellStartFrameRelativeToMainScreen(cell : PhotoCell) ->CGRect {
        let frame = cell.convertRect(cell.bounds, toCoordinateSpace: UIScreen.mainScreen().fixedCoordinateSpace)
        return frame
    }
    // 根据cell 计算cell对于主屏幕的frame
    private func cellEndFrame(cell : PhotoCell) ->CGRect {
        let image = cell.imageView!.image!
        var size = scaleImageSize(image, relateToWidth: UIScreen.mainScreen().bounds.size.width)
        let y = (UIScreen.mainScreen().bounds.height - size.height) * 0.5
        return CGRectMake(0, y, size.width, size.height)
    }
    // 计算图片缩放根据给定的宽度
    private func scaleImageSize(image : UIImage, relateToWidth width: CGFloat) -> CGSize {
        let imageW = image.size.width
        let imageH = image.size.height
        let scaleH = width * imageH / imageW
        return CGSizeMake(width, scaleH)
    }
    // 计算图片缩放根据给定的高度
    private func scaleImageSize(image : UIImage, relateToHeight height: CGFloat) -> CGSize {
        let imageW = image.size.width
        let imageH = image.size.height
        let scaleW = height * imageW / imageH
        return CGSizeMake(scaleW, height)
    }
    
    // 常规dismiss动画
    func normalDismiss(n : NSNotification) {
        // 根据通知得知正在看第几个图
        let index = n.userInfo!["index"] as! Int
        // 坐标
        let endFrame = endFrameList![index]
        let startFrame = startFrameList![index]
        // 动画
        dismissAnimation(startFrame, endFrame: endFrame, url: self.smallURLList![index], scale: 1)
    }
    // 交互式dismiss动画

    func interactiveDismissAnimation(n : NSNotification) {
        // 当前缩放比例
        let scale = n.userInfo!["scale"] as! CGFloat
        // 当前图片索引
        let index = (n.object as! NSNumber).integerValue
        // 坐标
        let endFrame = endFrameList![index]
        let startFrame = startFrameList![index]
        // 动画
        dismissAnimation(startFrame, endFrame: endFrame, url: self.smallURLList![index], scale: scale)
    }
    private func dismissAnimation(startFrame: CGRect, endFrame: CGRect, url : NSURL, scale : CGFloat){
        // 创建图片展示正在回去的图片
        let imageView = UIImageView(frame: endFrame)
        imageView.clipsToBounds = true
        imageView.sd_setImageWithURL(url)
        // 确定高度
        var height = endFrame.height * scale
        // 统一计算位置
        imageView.frame = CGRectMake(0, 0, endFrame.width * scale, height)
        imageView.center = CGPointMake(UIScreen.mainScreen().bounds.width * CGFloat(0.5), UIScreen.mainScreen().bounds.height * CGFloat(0.5))
        // 如果是长图，限制大小
        if endFrame.height > UIScreen.mainScreen().bounds.height {
            // Top属性
            imageView.contentMode = UIViewContentMode.Top
            // 大小设定
            let width = endFrame.width * scale
            let x = (UIScreen.mainScreen().bounds.width - width) * 0.5
            let y = x
            height = UIScreen.mainScreen().bounds.height - y
            imageView.frame = CGRectMake(x, y, width, height)
        }else{
            imageView.contentMode = UIViewContentMode.ScaleAspectFill
        }
        
        // 遮罩
        let backView = UIView(frame: UIScreen.mainScreen().bounds)
        backView.backgroundColor = UIColor.blackColor()
        backView.alpha = scale
        UIApplication.sharedApplication().keyWindow?.addSubview(backView)
        UIApplication.sharedApplication().keyWindow?.addSubview(imageView)
        // 开始动画
        UIView.animateWithDuration(AnimationDuration, animations: { () in
            // 获得需要回去的frame
            imageView.frame = startFrame
            backView.alpha = 0
            }, completion: {(finish) -> Void in
                // 移除动画视图
                imageView.removeFromSuperview()
                backView.removeFromSuperview()
                // 发送结束动画通知
                NSNotificationCenter.defaultCenter().postNotificationName(PhotoBrowserEndDismissNotification, object: nil)
                // 结束监听通知
                self.removeNotification()
        })

    }
    // 根据给定的frame, 计算center坐标
    private func calculateCenterPointWithRect(rect : CGRect) -> CGPoint {
        let x = rect.origin.x + rect.width * 0.5
        let y = rect.origin.y + rect.height * 0.5
        return CGPointMake(x, y)
    }
}
//MARK: - UICollectionViewDataSource数据源方法
extension PhotoBrowserScanViewController : UICollectionViewDataSource {

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // 计算自动布局
        calculateViewSize()
        return self.smallURLList?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reusedId, forIndexPath: indexPath) as! PhotoCell
        // 设置小图
        cell.url = smallURLList![indexPath.item]
        return cell
    }
}
//MARK: - UICollectionViewDelegate代理方法
extension PhotoBrowserScanViewController : UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        // 走之前注册通知
        regiserNotification()
        // 计算当前点击时候的全部cell的frame
        calculateFrameLists()
        // 准备跳转的视图
        let modalVC = PhotoBrowserViewController()
        // 将图像数组传递
        modalVC.largeImageURLList = largeURLList
        modalVC.smallImageURLList = smallURLList
        modalVC.index = indexPath.item
        modalVC.startFrameList = startFrameList
        modalVC.endFrameList = endFrameList
        
        // 根据点击cell截取动画图片
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCell
        var dummyView = cell.snapshotViewAfterScreenUpdates(false)
        // 设置遮罩view
        let backView = UIView(frame: UIScreen.mainScreen().bounds)
        backView.backgroundColor = UIColor.blackColor()
        backView.alpha = 0

        
        // 开始frame
        let startFrame = startFrameList![indexPath.item]
        let imageView = UIImageView(frame: startFrame)
        var endFrame = endFrameList![indexPath.item]
        imageView.sd_setImageWithURL(smallURLList![indexPath.item])
        if endFrame.height > UIScreen.mainScreen().bounds.height {
            // 拉伸小图，填充
            imageView.contentMode = UIViewContentMode.Top
            endFrame = UIScreen.mainScreen().bounds
        }else{
            imageView.contentMode = UIViewContentMode.ScaleAspectFill
        }
        imageView.clipsToBounds = true
        // 将遮罩添加到window
        UIApplication.sharedApplication().keyWindow?.addSubview(backView)
        UIApplication.sharedApplication().keyWindow?.addSubview(imageView)
        // 准备跳转
        modalVC.view.alpha = 0
        self.mk_presentViewController(modalVC, withPresentFrame: UIScreen.mainScreen().bounds, withPresentAnimation: { (_) -> NSTimeInterval in
            return 0.0
        }, withDismissAnimation: { (_) -> NSTimeInterval in
            return 0.0
        }) { () -> Void in
            UIView.animateWithDuration(self.AnimationDuration, animations: { () -> Void in
                imageView.frame = endFrame
                backView.alpha = 1
            }, completion: { (_) -> Void in
                modalVC.view.alpha = 1
                imageView.removeFromSuperview()
                backView.removeFromSuperview()
                if !(SDWebImageManager.sharedManager().cachedImageExistsForURL(modalVC.largeImageURLList![indexPath.item])) {
                    SVProgressHUD.show()
                }
                self.view.userInteractionEnabled = true

            })
        }
    }
}

