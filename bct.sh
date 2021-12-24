#!/bin/bash

#以下是用户可以自行设置的变量
savedir=$HOME/storage/shared/哔哩哔哩缓存操作工具输出/
save_filetype=mkv
name=bct 


#以下为常量，一般用户请勿修改
workdir_standard=$HOME/storage/shared/Android/data/tv.danmaku.bili/download/
workdir_global=$HOME/storage/shared/Android/data/com.bilibili.app.in/download/
softlist="ffmpeg jq find coreutils"

#加载函数到内存

func_message(){
case $1 in
	info)
        text=$2$3$4$5$6$7$8$9
        echo -e "\033[32m"[$name] [info] $text"\033[0m"
	;;
    error)
        text=$2$3$4$5$6$7$8$9
        echo -e "\033[31m"[$name] [error] $text"\033[0m"
	;;
	warning)
        text=$2$3$4$5$6$7$8$9
        echo -e "\033[33m"[$name] [warning] $text"\033[0m"
	;;
esac	
}
func_inputbox(){
while [ 0 ]
	do
		read -r -p '输入内容> ' return_val
		if [ -z $return_val ]
            then
                func_message error 输入不能为空
            else
                break
		fi
	done
}
func_storage_check(){
if [ -L $HOME/storage/shared ]
    then
		func_message info "存储权限 [YES]"
		true
	else
		func_message error "存储权限 [NO]"
		false
fi
}
func_getavlist(){
for avlist in $(ls -1 $1/)
	do
		echo av${avlist}
	done
}
func_getnum(){
	echo $1 | sed 's/av//' | tee
}
func_check_command(){
if command -v $1 > /dev/null
	then
		func_message info $1 " [YES]"
		true
	else
		func_message error $1 " [NO]"
		false
fi
}
#初始化函数
func_init_check(){
func_message info 正在检测存储权限
if func_storage_check
    then
		break
	else
		func_message warning 请授予Termux存储权限
		termux-setup-storage
fi
func_message info  正在检查软件 
for task_softname in ${softlist}
do
	if func_checkcmd $task_softname
	then
		true
	else
		func_message error 发生错误，软件$task_softname未安装
		func_message error "尝试使用如下命令: pkg in "$task_softname " 来安装该软件"
		exit 127
	fi
done
}
#m4s格式相关函数

func_m4s_file_check(){
    var_m4s_file_path=$1
    var_m4s_index_path=$2
    var_task_avnum=$3
    var_task_type_friendly=$4
    var_task_type=$5
if [ $(md5sum ${var_m4s_file_path}|cut -d ' ' -f 1) = $(cat ${var_m4s_index_path}|jq ".${var_task_type}[0]"|jq '.md5'|sed 's/"//g') ]
	then
		func_message info ${task_avnum}的${var_task_type_friendly}检验成功
		true
	else
		func_message error ${var_task_type_friendly}已损坏，可能是缓存未完毕，请返回客户端，重新下载重试
		false
fi
}

# 全部函数已加载到内存

# 程序主逻辑

set -o pipefail
set -o errexit



#工作进程主函数
func_m4s_video_pack(){
#检测savedir是否存在，不存在自动创建，创建失败抛出错误退出
if [ -d $savedir ]
then
	true
else
	func_message warning 保存目录不存在，正在尝试自动创建保存目录
	if mkdir $savedir
	then
		func_message info 自动创建成功
		true
	else
		func_message error 创建失败，可能是含有未预期的嵌套目录，请手动创建重试
		exit 11
	fi
fi
#检测workdir是否存在，内部是否有文件，没有则抛出错误代码退出
if [ -d $workdir ]
then
	true
else
	func_message error 请确认应用程序是否安装
	exit 12
fi
#检测workdir目录是否为空
if [ $(ls -A $workdir |wc -l) = 0  ]
then
	func_message error 啥都木有，无需任何操作
	exit 13
else
	true
fi
#视频封装部分

for task_avnum in $(func_getavlist $workdir)
do	
	#定义并初始化，每个所需文件的位置
	task_audiofile=$(find ${workdir}/$(func_getnum $task_avnum) -name audio.m4s)
	task_videofile=$(find ${workdir}/$(func_getnum $task_avnum) -name video.m4s)
	task_indexfile=$(find ${workdir}/$(func_getnum $task_avnum) -name index.json)

	if [ -z ${task_videofile} ]
		then
			func_message error 发生错误:${task_avnum}的视频文件未找到，请前往客户端删除重试
			break
		else
			true
	fi
	
	if [ -z ${task_audiofile} ]
		then
			func_message error 发生错误:${task_avnum}的音频文件未找到，请前往客户端删除重试
			break
		else
			true
	fi
	
	if [ -z ${task_indexfile} ]
		then
			func_message error 发生错误:${task_avnum}的索引文件未找到，请前往客户端删除重试
			break
		else
			true
	fi
	

	#最外层判断，判断文件是否存在，如果存在，直接跳过
	if [ -f ${savedir}/${task_avnum}.${save_filetype} ]
		then
			true
	else
		if func_m4s_file_check $task_videofile $task_indexfile $task_avnum 视频 video
		then
			true
		else
			break
		fi
		if func_m4s_file_check $task_audiofile $task_indexfile $task_avnum 音频 audio
		then
			true
		else
			break
		fi
                true
		#使用ffmpeg合成视频
		ffmpeg -i ${task_audiofile} -i ${task_videofile} -codec copy ${savedir}/${task_avnum}.${save_filetype}
	fi
	#最外层判断结束
done
}

while [ 0 ]
do
	func_message info 请输入行动
	func_message info '0(退出)'
	func_message info '1(开始导出并合并视频[国内版])'
	func_message info '2(开始导出并合并视频[谷歌版])'
	func_inputbox
	case $return_val in
		0|q)
			break
		;;
		1)
			workdir=${workdir_standard} func_m4s_video_pack
			func_message info 操作完毕
		;;
		2)
			workdir=${workdir_global} func_m4s_video_pack
			func_message info 操作完毕
		;;
		*)
			func_message error 未预期的输入
		;;
esac
done
