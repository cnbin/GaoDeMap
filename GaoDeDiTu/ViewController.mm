//
//  ViewController.m
//  GaoDeDiTu
//
//  Created by Apple on 9/14/15.
//  Copyright (c) 2015 广东华讯网络投资有限公司. All rights reserved.
//


#import "ViewController.h"
#import "KZStatusView.h"
#import "MZTimerLabel.h"
#import <MAMapKit/MAMapKit.h>

#define DeviceWidth  [[UIScreen mainScreen]bounds].size.width
#define DeviceHeight [[UIScreen mainScreen]bounds].size.height

typedef enum : NSUInteger {
    TrailStart,
    TrailEnd
} Trail;

@interface ViewController ()<MAMapViewDelegate>

/** 高德地图View */
@property (nonatomic, strong) MAMapView * mapView;

/** 半透明状态显示View */
@property (nonatomic,strong) KZStatusView *statusView;

/** 记录上一次的位置 */
@property (nonatomic, strong) CLLocation *preLocation;

/** 位置数组 */
@property (nonatomic, strong) NSMutableArray *locationArrayM;

/** 轨迹线 */
@property (nonatomic, strong) MAPolyline *polyLine;

/** 轨迹记录状态 */
@property (nonatomic, assign) Trail trail;

/** 起点大头针 */
@property (nonatomic, strong) MAPointAnnotation *startPoint;

/** 终点大头针 */
@property (nonatomic, strong) MAPointAnnotation *endPoint;

/** 累计步行时间 */
@property (nonatomic,assign) NSTimeInterval sumTime;

/** 累计步行距离 */
@property (nonatomic,assign) CGFloat sumDistance;

///** 记录大头针 */
//@property (nonatomic, strong) NSMutableArray *annotations;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //self.annotations = [NSMutableArray array];

    [MAMapServices sharedServices].apiKey = @"e1c12489a0507c51c6bbb06657238088";

    // 初始化导航栏的一些属性
    [self setupNavigationProperty];
    
    // 初始化 状态信息 控制器
    self.statusView = [[KZStatusView alloc]init];
    
    // 初始化地图窗口
    self.mapView = [[MAMapView alloc]initWithFrame:self.view.bounds];
    
    // 设置MapView的一些属性
    [self setMapViewProperty];
    
    CLLocationCoordinate2D coor ={23.5610,116.3532};
    self.mapView.centerCoordinate = coor;

    self.trail = TrailEnd;
    
    [self.view addSubview:self.mapView];
    [self.view addSubview:self.statusView.view];
    
//    [self.mapView addAnnotations:self.annotations];
//    [self.mapView showAnnotations:self.annotations edgePadding:UIEdgeInsetsMake(20, 20, 20, 80) animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.mapView.delegate = self;
    self.navigationController.navigationBar.barStyle    = UIBarStyleBlack;
    self.navigationController.navigationBar.translucent = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    self.mapView.delegate = nil;
    self.mapView = nil;
}


- (void)viewWillLayoutSubviews
{
    self.statusView.view.frame = CGRectMake(20, DeviceHeight - 270, 338, 261);
}

#pragma mark - Customize Method

/**
 *  设置导航栏的一些属性
 */
- (void)setupNavigationProperty
{
    // 导航栏中部标题
    self.title = @"轨迹记录";
    
    // 导航栏左侧按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"开始记录"
                                                                            style:UIBarButtonItemStylePlain
                                                                           target:self
                                                                           action:@selector(startTrack)];
    // 导航栏右侧按钮
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"停止记录"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(stopTrack)];
}

/**
 *  设置高德MapView的一些属性
 */
- (void)setMapViewProperty
{
    // 设置定位模式
    self.mapView.userTrackingMode = MAUserTrackingModeNone;
}

#pragma mark - "IBAction" Method

/**
 *  开启高德地图定位服务
 */
- (void)startTrack
{
    // 1.清理上次遗留的轨迹路线以及状态的残留显示
    [self clean];

    // 2.打开定位服务
    // 显示定位图层
    self.mapView.showsUserLocation = YES;
    
    // 3.更新状态栏的“是否打开地理位置服务”的 Label
    self.statusView.startLocatonServiceLabel.text = @"YES";
    self.statusView.stopLocatonServiceLabel.text = @"NO";
    self.statusView.startPointLabel.text = @"YES";
    
    CLLocationCoordinate2D center;
    center.latitude = 23.5610;
    center.longitude = 116.3532;

    MACoordinateRegion adjustRegion = [self.mapView regionThatFits:MACoordinateRegionMake(center,MACoordinateSpanMake(0.02f,0.02f))];

    [self.mapView setRegion:adjustRegion animated:YES];
    
    
    // 5.如果计时器在计时则复位
    if ([self.statusView.timerLabel counting] || self.statusView.timerLabel.text != nil) {
        [self.statusView.timerLabel reset];
    }
    
    // 6.开始计时
    [self.statusView.timerLabel start];

    // 7.设置轨迹记录状态为：开始
    self.trail = TrailStart;
}

/**
 *  停止高德地图定位
 */
- (void)stopTrack
{
    // 1.停止计时器
    [self.statusView.timerLabel pause];
    
    // 2.更新状态栏的“是否打开地理位置服务”的 Label
    self.statusView.startLocatonServiceLabel.text = @"NO";
    self.statusView.stopLocatonServiceLabel.text = @"YES";
    self.statusView.stopPointLabel.text = @"YES";
    
    // 3.设置轨迹记录状态为：结束
    self.trail = TrailEnd;

    // 4.关闭定位服务
    self.mapView.showsUserLocation = NO;
    
    // 5.添加终点旗帜
    self.endPoint = [self creatPointWithLocaiton:self.preLocation title:@"终点"];
    
    [self.mapView clearDisk];
}

#pragma mark - MADelegate
/**
 *  定位失败会调用该方法
 *
 *  @param error 错误信息
 */
- (void)didFailToLocateUserWithError:(NSError *)error
{
    NSLog(@"did failed locate,error is %@",[error localizedDescription]);
    UIAlertView *gpsWeaknessWarning = [[UIAlertView alloc]initWithTitle:@"Positioning Failed" message:@"Please allow to use your Location via Setting->Privacy->Location" delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil, nil];
    [gpsWeaknessWarning show];
}

/*!
 @brief 在地图View停止定位后调用此接口
 @param mapView 地图View
 */
- (void)mapViewDidStopLocatingUser:(MAMapView *)mapView{
    
}


/**
 *  用户位置更新后，会调用此函数
 *  @param userLocation 新的用户位置
 */
-(void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation
updatingLocation:(BOOL)updatingLocation
{

    // 1. 动态更新我的位置数据
    //[self.mapView updateLocationData:userLocation];
    NSLog(@"La:%f, Lo:%f", userLocation.location.coordinate.latitude, userLocation.location.coordinate.longitude);

    // 2. 更新状态栏的经纬度 Label
    self.statusView.latituteLabel.text = [NSString stringWithFormat:@"%.4f",userLocation.location.coordinate.latitude];
    self.statusView.longtituteLabel.text = [NSString stringWithFormat:@"%.4f",userLocation.location.coordinate.longitude];
    self.statusView.avgSpeed.text = [NSString stringWithFormat:@"%.2f",userLocation.location.speed];

    // 3. 如果精准度不在10米范围内
    if (userLocation.location.horizontalAccuracy > kCLLocationAccuracyNearestTenMeters) {
        NSLog(@"userLocation.location.horizontalAccuracy is %f",userLocation.location.horizontalAccuracy);
//        UIAlertView *gpsSignal = [[UIAlertView alloc]initWithTitle:@"GPS Signal" message:@"Hey,GPS Signal is terrible,please move your body..." delegate:nil cancelButtonTitle:@"okay" otherButtonTitles:nil, nil];
//        [gpsSignal show];
        return;
    }
    
    // 开始记录轨迹
   if (TrailStart == self.trail) {
       
       if (userLocation.location.coordinate.latitude >0 && userLocation.location.coordinate.longitude >0 ){
           
           [self startTrailRouteWithUserLocation:userLocation];
       }
    }
    
}

#pragma mark - Selector for didUpdateBMKUserLocation:
- (void)startTrailRouteWithUserLocation:(MAUserLocation *)userLocation
{
    if (self.preLocation) {
        // 计算本次定位数据与上次定位数据之间的时间差
        NSTimeInterval dtime = [userLocation.location.timestamp timeIntervalSinceDate:self.preLocation.timestamp];

        // 累计步行时间
        self.sumTime += dtime;
        self.statusView.sumTime.text = [NSString stringWithFormat:@"%.2f",self.sumTime];

        // 计算本次定位数据与上次定位数据之间的距离
        CGFloat distance = [userLocation.location distanceFromLocation:self.preLocation];
        self.statusView.distanceWithPreLoc.text = [NSString stringWithFormat:@"%.2f",distance];
        NSLog(@"与上一位置点的距离为:%f",distance);

        // (5米门限值，存储数组划线) 如果距离少于 5 米，则忽略本次数据直接返回该方法
        if (distance < 2) {
            NSLog(@"与前一更新点距离小于5m，直接返回该方法");
            return;
        }

        // 累加步行距离
        self.sumDistance += distance;
        self.statusView.distance.text = [NSString stringWithFormat:@"%.2f",self.sumDistance / 1000.0];
        NSLog(@"步行总距离为:%f",self.sumDistance);

        // 计算移动速度
        CGFloat speed = distance / dtime;
        self.statusView.currSpeed.text = [NSString stringWithFormat:@"%.2f",speed];

        // 计算平均速度
        CGFloat avgSpeed  =self.sumDistance / self.sumTime;
        self.statusView.avgSpeed.text = [NSString stringWithFormat:@"%.2f",avgSpeed];
    }

    // 2. 将符合的位置点存储到数组中
    if (userLocation.location != nil) {
        
        [self.locationArrayM addObject:userLocation.location];
    }
    self.preLocation = userLocation.location;

    // 3. 绘图
    [self drawWalkPolyline];

}

- (void)drawWalkPolyline
{
    // 轨迹点
    NSUInteger count = self.locationArrayM.count;

    // 手动分配存储空间，结构体：地理坐标点，用直角地理坐标表示 X：横坐标 Y：纵坐标
     MAMapPoint  * tempPoints = new MAMapPoint[count];
    
    [self.locationArrayM enumerateObjectsUsingBlock:^(CLLocation *location, NSUInteger idx, BOOL *stop) {
        MAMapPoint locationPoint = MAMapPointForCoordinate(location.coordinate);
        tempPoints[idx] = locationPoint;
        
        // 放置起点旗帜
        if (0 == idx && TrailStart == self.trail && self.startPoint == nil) {
            
           self.startPoint = [self creatPointWithLocaiton:location title:@"起点"];
        }
    }];
    
    //移除原有的绘图
    if (self.polyLine) {
        [self.mapView removeOverlay:self.polyLine];
    }

    // 通过points构建BMKPolyline
    self.polyLine = [MAPolyline polylineWithPoints:tempPoints count:count];

    //添加路线,绘图
    if (self.polyLine) {
        [self.mapView addOverlay:self.polyLine];
    }
    
    // 清空 tempPoints 内存
    delete []tempPoints;

    [self mapViewFitPolyLine:self.polyLine];
}


/**
 *  添加一个大头针
 *
 *  @param location
 */
- (MAPointAnnotation *)creatPointWithLocaiton:(CLLocation *)location title:(NSString *)title;
{
    
    MAPointAnnotation *point = [[MAPointAnnotation alloc] init];
    point.coordinate = location.coordinate;
    point.title = title;
   [self.mapView addAnnotation:point];
    
   // [self.annotations addObject:point];
    
    return point;
}

/**
 *  清空数组以及地图上的轨迹
 */
- (void)clean
{
    // 清空状态栏信息
    self.statusView.distance.text = nil;
    self.statusView.avgSpeed.text = nil;
    self.statusView.currSpeed.text = nil;
    self.statusView.sumTime.text = nil;
    self.statusView.latituteLabel.text = nil;
    self.statusView.longtituteLabel.text = nil;
    self.statusView.distanceWithPreLoc.text = nil;
    self.statusView.startLocatonServiceLabel.text = @"NO";
    self.statusView.stopLocatonServiceLabel.text = @"YES";
    self.statusView.startPointLabel.text = @"NO";
    self.statusView.stopPointLabel.text = @"NO";
    
    //清空数组
    [self.locationArrayM removeAllObjects];

    [self.mapView removeAnnotation:self.startPoint];
    self.startPoint = nil;

    [self.mapView removeAnnotation:self.endPoint];
    self.endPoint = nil;

    [self.mapView removeOverlay:self.polyLine];
    self.polyLine = nil;
    
}

/**
 *  根据polyline设置地图范围
 *
 *  @param polyLine
 */
- (void)mapViewFitPolyLine:(MAPolyline *) polyLine {
    CGFloat ltX, ltY, rbX, rbY;
    if (polyLine.pointCount < 1) {
        return;
    }
    MAMapPoint pt = polyLine.points[0];
    ltX = pt.x, ltY = pt.y;
    rbX = pt.x, rbY = pt.y;
    for (int i = 1; i < polyLine.pointCount; i++) {
        MAMapPoint pt = polyLine.points[i];
        if (pt.x < ltX) {
            ltX = pt.x;
        }
        if (pt.x > rbX) {
            rbX = pt.x;
        }
        if (pt.y > ltY) {
            ltY = pt.y;
        }
        if (pt.y < rbY) {
            rbY = pt.y;
        }
    }
    MAMapRect rect;
    rect.origin = MAMapPointMake(ltX , ltY);
    rect.size = MAMapSizeMake(rbX - ltX, rbY - ltY);
    [self.mapView setVisibleMapRect:rect];
    self.mapView.zoomLevel = self.mapView.zoomLevel - 0.3;
}

#pragma mark - MAMapViewDelegate

/**
 *  根据overlay生成对应的View
 *  @param mapView 地图View
 *  @param overlay 指定的overlay
 *  @return 生成的覆盖物View
 */
- (MAOverlayRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id <MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[MAPolyline class]])
    {
        MAPolylineRenderer *polylineRenderer = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        polylineRenderer.lineWidth   = 8.f;
        polylineRenderer.strokeColor = [[UIColor redColor] colorWithAlphaComponent:0.7];
        return polylineRenderer;
    }
    
    return nil;
}

/**
 *  只有在添加大头针的时候会调用，直接在viewDidload中不会调用
 *  根据anntation生成对应的View
 *  @param mapView 地图View
 *  @param annotation 指定的标注
 *  @return 生成的标注View
 */
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id <MAAnnotation>)annotation
{
        if ([annotation isKindOfClass:[MAPointAnnotation class]]) {
        static NSString *pointReuseIndentifier = @"pointReuseIndentifier";
        MAPinAnnotationView * annotationView = (MAPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndentifier];
        if (annotationView == nil)
        {
            annotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndentifier];
        }
            annotationView.pinColor = MAPinAnnotationColorGreen;
    
        // 从天上掉下效果
        annotationView.animatesDrop = YES;
        // 不可拖拽
        annotationView.draggable = NO;

        return annotationView;
    }
    return nil;
}

#pragma mark - lazyLoad

- (NSMutableArray *)locationArrayM
{
    if (_locationArrayM == nil) {
        _locationArrayM = [NSMutableArray array];
    }
    
    return _locationArrayM;
}

@end
