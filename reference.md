# 移植指南参考
https://gitee.com/openharmony/docs/blob/master/zh-cn/device-dev/porting/porting-linux-kernel.md


# 使用三方Linux内核时需要移植的OpenHarmony补丁和需要打开的宏
一、需要的OpenHarmony补丁
1、HDF patch
已有patch
kernel/linux/patches/linux-5.10/common_patch/hdf.patch
可参考rk3568合入HDF patch

2、DFX patch
内核下源码位置:
drivers/staging/hilog
drivers/staging/hievent

3、Access Token patch安全增强
内核下源码位置:
drivers/accesstokenid

其他文件有少量修改，主要看下面这连个链接合入：
https://gitee.com/openharmony/kernel_linux_4.19/pulls/4
https://gitee.com/openharmony/kernel_linux_4.19/pulls/5

4、HMDFS 分布式文件系统
内核下源码位置:

fs/hmdfs

 

二、需要打开的宏
1、HDF相关的宏
```
CONFIG_DRIVERS_HDF=y
CONFIG_HDF_SUPPORT_LEVEL=2
CONFIG_DRIVERS_HDF_PLATFORM=y
CONFIG_DRIVERS_HDF_PLATFORM_GPIO=y
CONFIG_DRIVERS_HDF_PLATFORM_I2C=y
CONFIG_DRIVERS_HDF_INPUT=y
CONFIG_DRIVERS_HDF_TP_5P5_GT911=y
CONFIG_DRIVERS_HDF_SENSOR=y
CONFIG_DRIVERS_HDF_SENSOR_ACCEL=y
CONFIG_DRIVERS_HDF_SENSOR_ACCEL_BMI160=y
CONFIG_DRIVERS_HDF_SENSOR_ACCEL_MXC6655XA=y
CONFIG_DRIVERS_HDF_USB_PNP_NOTIFY=y
CONFIG_DRIVERS_HDF_VIBRATOR=y
CONFIG_DRIVERS_HDF_VIBRATOR_LINEAR=y
CONFIG_DRIVERS_HDF_DSOFTBUS=y
CONFIG_DRIVERS_HDF_LIGHT=y
```
更多HDF宏，可根据业务需要开启。

 

2、其他宏
```
#
# BINDER //相关的宏，影响系统进程间通信；如不开启，系统服务会起不了
#

CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y  
# CONFIG_ANDROID_BINDERFS is not set
CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
# CONFIG_ANDROID_BINDER_IPC_SELFTEST is not set
CONFIG_BINDER_TRANSACTION_PROC_BRIEF=y   //如不开启，AppFrezee日志中binder信息会缺失

 

CONFIG_ACCESS_TOKENID=y  //如不开启，softbus会起不来，Launcher起不来
CONFIG_ASHMEM=y  //如不开启，foundation会起不了，Launcher起不来
CONFIG_TLS=y
CONFIG_UNIX_SCM=y
CONFIG_STREAM_PARSER=y
CONFIG_NET_SOCK_MSG=y
CONFIG_BLK_DEV_INITRD=y

 

#
# HMDFS  //分布式文件系统相关的宏，影响媒体资源库
#

CONFIG_HMDFS_FS=y
CONFIG_HMDFS_FS_PERMISSION=y
CONFIG_HMDFS_FS_ENCRYPTION=y

 

#
# HYPERHOLD  //HYPERHOLD相关的宏，影响memmgr内存管理服务
#
CONFIG_HYPERHOLD=y
CONFIG_HYPERHOLD_DEBUG=y
CONFIG_HYPERHOLD_ZSWAPD=y
CONFIG_HYPERHOLD_FILE_LRU=y
CONFIG_HYPERHOLD_MEMCG=y
# CONFIG_ZRAM_GROUP=y
# CONFIG_ZRAM_GROUP_DEBUG=y
CONFIG_ZLIST_DEBUG=y
# CONFIG_ZRAM_GROUP_WRITEBACK=y
```