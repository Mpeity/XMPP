//
//  ViewController.m
//  XMPP_wechat
//
//  Created by nick_beibei on 16/3/23.
//  Copyright © 2016年 nick_beibei. All rights reserved.
//

#import "ViewController.h"
#import <CoreData/CoreData.h>


#define  kWidth [UIScreen mainScreen].bounds.size.width
#define  kHeight [UIScreen mainScreen].bounds.size.height

@interface ViewController ()<NSStreamDelegate,UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>
{
    NSInputStream *_inputStream;
    NSOutputStream *_outputStream;
}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

// 存储所有聊天记录的数组
@property (nonatomic,strong) NSMutableArray *msgArray;



@end

@implementation ViewController

// 懒加载一下
- (NSMutableArray *)msgArray {
    if (!_msgArray) {
        _msgArray = [NSMutableArray array];
    }
    return _msgArray;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    // 添加键盘通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(kbWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 键盘将显示
- (void)kbWillShow:(NSNotification *)notification {
    // 显示的时候改变bottomConstraint(约束)
    // 获取键盘的高度
    NSLog(@"%@",notification.userInfo);
    CGFloat kbHeight = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    self.bottomConstraint.constant = kbHeight;
}

#pragma mark - 键盘将隐藏
- (void)kbWillHide:(NSNotification *)notification {
    self.bottomConstraint.constant = 0;

}

#pragma mark - textFieldDelegate 返回按钮监听
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // 发送聊天数据
    // 1.有数据才发送
    NSString *txt = textField.text;
    if (txt.length == 0) {
        return YES;
    }
    // 发送数据
    NSString *msg = [@"msg:" stringByAppendingString:txt];
    [self sendDataToHost:msg];
    return YES;
}

#pragma mark - 发送数据
- (void)sendDataToHost:(NSString *)string {
    
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    [_outputStream write:data.bytes maxLength:data.length];}

#pragma mark - 表格的数据源
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.msgArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *chatCell = @"chatCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:chatCell forIndexPath:indexPath];
    cell.textLabel.text = self.msgArray[indexPath.row];
    return cell;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView {
    // 隐藏键盘
    [self.view endEditing:YES];
}


#pragma mark - 连接
- (IBAction)connectToServer:(id)sender {
    //ios里实现socket的连接，使用C语言
    
    // 1.与服务器三次握手建立连接
    NSString *host = @"127.0.0.1"; //ip
    int port = 12345; // 端口号
    
    // 2.定义输入输出流
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    // 3.分配输入输出流的内存空间
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)host, port, &readStream, &writeStream);
    // 4.把C语言的输入输出流转成OC对象
    _inputStream = (__bridge NSInputStream *)readStream;
    _outputStream = (__bridge NSOutputStream *)(writeStream);
    
    // 5.设置代理，监听数据接收的状态
    _outputStream.delegate = self;
    _inputStream.delegate = self;
    
    // 把输入输出流添加到主运行循环(RunLoop)
    // 主运行循环是监听网络状态
    [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    
    // 6.打开输入输出流
    [_inputStream open];
    [_outputStream open];
}

#pragma  mark - NSStreamDeleagate
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
//    NSStreamEventNone = 0,
//    NSStreamEventOpenCompleted = 1UL << 0,
//    NSStreamEventHasBytesAvailable = 1UL << 1,
//    NSStreamEventHasSpaceAvailable = 1UL << 2,
//    NSStreamEventErrorOccurred = 1UL << 3,
//    NSStreamEventEndEncountered = 1UL << 4
    
    // 代理的回调在主线程
    
    NSLog(@"%@",[NSThread currentThread]);
    switch (eventCode) {
        case NSStreamEventOpenCompleted:
            NSLog(@"成功建立连接，形成输入输出流的传输通道");
            break;
        case NSStreamEventHasBytesAvailable:
            [self readData];
            NSLog(@"有数据可读");
            break;
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"可以发送数据");
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"有错误发生，连接失败");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"正常的断开连接");
            // 把输入输出流关掉，而且还要从主运行循环移除
            [_inputStream close];
            [_outputStream close];
            [_inputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            [_outputStream removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
            break;
            
        default:
            break;
    }
}

#pragma mark - 读取服务器返回的数据
- (void)readData {
    
    // 定义一个缓冲区 这个缓冲区只能存储1024个字节
    uint8_t buf[1024];
    
    // 使用输入流读取数据
    // len为服务器读取到的实际字节数
    NSInteger len = [_inputStream read:buf maxLength:sizeof(buf)];
    
    // 把缓冲区里的实际字节数转成字符串
    NSString *recieveStr = [[NSString alloc] initWithBytes:buf length:len encoding:NSUTF8StringEncoding];
    NSLog(@"%@",recieveStr);
    
    // 把数据添加到数组msgArray里面
    [self.msgArray addObject:recieveStr];
    
    //刷新数据
    [self.chatTableView reloadData];
}

#pragma mark - 登录
- (IBAction)loginBtnClick:(id)sender {
    // 发送登录请求 使用输出流（输出流是写数据的）
    
    // 拼接登录的指令 iam：zhangsan
    NSString *loginStr = @"iam:zhangsan";
    // uint8_t *  字符数组
    NSData *data = [loginStr dataUsingEncoding:NSUTF8StringEncoding];
    [_outputStream write:data.bytes maxLength:data.length];
    
}

//移除通知
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
