# LXStatusHUD

![](Screenshot/LXStatusHUD.gif)

在[《一款Loading动画的实现思路》](http://www.jianshu.com/p/1c6a2de68753)这篇博客看到的，照着这种效果自己实现了下。

```objective-c
[LXStatusHUD showSuccess];
[LXStatusHUD showFailure];
```

```objective-c
[LXStatusHUD showSuccessWithConfiguration:^(id<LXHUDConfiguration> configurer) {
    configurer.checkmarkColor = [UIColor greenColor];
}];

[LXStatusHUD showFailureWithConfiguration:^(id<LXHUDConfiguration> configurer) {
    configurer.radius = 60;
    configurer.lineWidth = 15;
    configurer.exclamationColor = [UIColor orangeColor];
}];
```
