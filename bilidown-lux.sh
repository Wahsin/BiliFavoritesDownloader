#!/bin/bash
lux=/usr/local/bin/lux
echo "=========CURRENT TIME: `date`==========="
#telegram参数
telegram_bot_token=""
telegram_chat_id=""
#RSS 地址 自建rsshub的话就写:127.0.0.1 默认端口为 :1200 例：127.0.0.1:1200
rssURL="http://127.0.0.1:1200/bilibili/$1/$2/$3"
#脚本存放地址
scriptLocation="/root/BiliFavoritesDownloader/bili-cookies/"
#视频存放地址
videoLocation="/root/BiliFavoritesDownloader/bili-down/$4"

function urlencode() {
  which "curl" >/dev/null 2>&1; if [ ! $? -eq 0 ]; then echo -E "$1";return; fi
  encode_str=$(echo -E "$1" |sed "s/%/%%/g")
  printf -- "$encode_str" | curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" |cut -c 3-
}

#抓取rss更新
#echo "rssurl: $rssURL"
content=$(wget $rssURL -q -O -)
#content=`cat tmp.xml`

#get first item
tfirstItem=${content#*<item>}
firstItem=${tfirstItem%%</item>*}
#echo $firstItem

#get pubdate
tpubdate=${firstItem#*<pubDate>}
pubdate=${tpubdate%%</pubDate>*}
cur_sec=`date '+%s'`

#get title #todo
ttitle=${firstItem#*<title>}
subname=${ttitle#*\[CDATA\[}
oname=${subname%%\]\]>*}
#subname=${ttitle%%</title>*}
name=$(echo "$oname" | sed 's/\//\ /g')

#Get author
tauthor=${firstItem#*<author>}
author=${tauthor%%</author>*}
author=$(echo "$author" | sed 's/.*<!\[CDATA\[\(.*\)\]\]>.*/\1/g')
#echo "author: $author"

#Get desc
tdesc=${firstItem#*<description>}
desc=${tdesc%%<br><br><iframe*} #todo 两种格式

#get link
tlink=${firstItem#*<link>}
link=${tlink%%</link>*}

#如果时间戳记录文本不存在则创建（此处文件地址自行修改）
if [ ! -f "${scriptLocation}date.txt" ]; then
    echo 313340 >"$scriptLocation"date.txt
fi
#如果标题记录文本不存在则创建
if [ ! -f "${scriptLocation}title.txt" ]; then
    echo 313340 >"${scriptLocation}"title.txt
fi
#如果BV记录文本不存在则创建
if [ ! -f "${scriptLocation}BV.txt" ]; then
    echo 313340 >"${scriptLocation}"BV.txt
fi
#获得之前下载过的视频标题
oldtitle=$(cat "${scriptLocation}"title.txt)
#echo $oldtitle
#获得上一个视频的时间戳（文件地址自行修改）
olddate=$(cat "${scriptLocation}"date.txt)
#echo $olddate
#获得上一个视频的BV号
oldBV=$(cat "${scriptLocation}"BV.txt)
#echo $oldBV

#此处为视频存储位置，自行修改
filename="$videoLocation/$author/$name"
echo "filename: $filename"

av=${link#*video/}

result=$(echo $pubdate | grep "GMT")
result5=$(echo $oldtitle | grep "$name")
existDuplicateAV=$(echo $oldBV | grep "$av")
echo "result: $result"
echo "pubdate: $pubdate"
echo "olddate: $olddate"
echo "existDuplicateAV: $existDuplicateAV"

#判断当前时间戳和上次记录是否相同，不同则代表收藏列表更新
if [ "$result" != "" ] && [ "$existDuplicateAV" = "" ]; then

    #Cookies可用性检查
    stat=$($lux -i -c "$scriptLocation"cookies.txt https://www.bilibili.com/video/BV1fK4y1t7hj)
    #echo "Cookies 状态：$stat"
    substat=${stat#*Quality:}
    data=${substat%%#*}
    quality=${data%%Size*}
    #echo $quality

    #没会员，最高 1080P
    if [[ $quality =~ "1080P" ]]; then
        #清空 Bilibili 文件夹
        rm -rf "$videoLocation"*
        echo "cleardone"

        #获得封面图下载链接和文件名称  #todo
        tfanart=${firstItem#*<img src=\"}
        photolink=${tfanart%%\"*}
        pname=${photolink#*archive/}
        echo $photolink
        echo $pname
        #下载封面图（图片存储位置应和视频一致）
        wget -P "$filename" $photolink

        #记录时间戳
        echo $pubdate >"${scriptLocation}"date.txt
        #记录标题
        echo $name >>"${scriptLocation}"title.txt
        #记录BV号
        echo $av >>"${scriptLocation}"BV.txt
                echo $av >"$scriptLocation"av.txt
        echo $link >"$scriptLocation"link.txt

        #获取视频清晰度以及大小信息
        stat=$($lux -i -c "$scriptLocation"cookies.txt $link)
        #有几P视频
        count=$(echo $stat | awk -F'Title' '{print NF-1}')
        echo "count: $count"
        for ((i = 0; i < $count; i++)); do
                        stat=${stat#*Title:}
                        title=${stat%%Type:*}
                        substat=${stat#*Quality:}
                        data=${substat%%#*}
                        quality=${data%%Size*}
                        size=${data#*Size:}
                        title=$(echo $title)
                        quality=$(echo $quality)
                        size=$(echo $size)
                        #每一P的视频标题，清晰度，大小，发邮件用于检查下载是否正确进行
                        #message=${message}"Title: "${title}$'\n'"Quality: "${quality}$'\n'"Size: "${size}$'\n\n' #邮件方式
                        message=${message}"Title:%20"${title}"%0AQuality:%20"${quality}"%0ASize:%20"${size}"%0A%0A" #telegram方式
        done
                #发送开始下载邮件（自行修改邮件地址）
        #echo "$message" | mail -s "BFD：开始下载" $mailAddress
        #curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>BFD：开始下载</b>%0A%0A$message"
        #下载视频到指定位置（视频存储位置自行修改；下载B站经常会出错，所以添加了出错重试代码）
        echo "message: $message"
        #curl https://api.day.app/k5HuXmfTUPp3jPfVi3jCkm/$message
        count=1
        echo "1" > "${scriptLocation}${cur_sec}mark.txt"
        while true; do
            $lux -C -c "$scriptLocation"cookies.txt -o "$filename" $link > "${scriptLocation}${cur_sec}.txt" #如果是邮件通知，删除 > "${scriptLocation}${cur_sec}.txt"
            if [ $? -eq 0 ]; then
                #下载完成
                echo "0" > "${scriptLocation}${cur_sec}mark.txt"
                #重命名封面图
                result1=$(echo $pname | grep "jpg")
                if [ "$result1" != "" ]; then
                    mv "$filename"/$pname "$filename"/poster.jpg
                else
                    mv "$filename"/$pname "$filename"/poster.png
                fi
                #xml转ass && 获取下载完的视频文件信息
                for file in "$filename"/*; do
                    if [ "${file##*.}" = "xml" ]; then
                        "${scriptLocation}"DanmakuFactory -o "${file%%.cmt.xml*}".ass -i "$file"
                        #删除源文件
                        #rm "$file"
                    elif [ "${file##*.}" = "mp4" ] || [ "${file##*.}" = "flv" ] || [ "${file##*.}" = "mkv" ]; then
                        videoname=${file#*"$name"\/}
                        videostat=$(du -h "$file")
                        videosize=${videostat%%\/*}
                        videosize=$(echo $videosize)
                        videomessage=${videomessage}" "${videoname}$'\n'"Size: "${videosize}$'\n\n'  #邮件方式
                        #videomessage=${videomessage}"Title:%20"${videoname}"%0ASize:%20"${videosize}"%0A%0A" #telegram方式
                    fi

                    # 设置 nfo 文件内容 保持和视频文件名称一致
                echo $videoname
                nfo_file="$filename"/"${videoname:0:$((${#videoname}-3))}nfo"
                echo "$nfo_file"
                echo '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' > "$nfo_file"
                echo '<movie>' >> "$nfo_file"
                echo "  <plot>$desc <br><a href=$link>原链接</a>]]></plot>" >> "$nfo_file"
                echo "  <dateadded>$(date)</dateadded>" >> "$nfo_file"
                echo "  <title>$title</title>" >> "$nfo_file"
                echo '  <actor>' >> "$nfo_file"
                echo "          <name>$author</name>" >> "$nfo_file"
                echo '  </actor>' >> "$nfo_file"
                echo "  <trailer>$link</trailer>" >> "$nfo_file"
                echo "  <website>$link</website>" >> "$nfo_file"
                echo "  <releasedate>$pubdate</releasedate>" >> "$nfo_file"
                echo '</movie>' >> "$nfo_file"

                #echo "$nfo_content" > "$filename"/movie.nfo
                done
                #发送下载完成邮件
                #echo "$videomessage" | mail -s "BFD：下载完成" $mailAddress
                #curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>BFD：下载完成</b>%0A%0A$videomessage"
                #上传至OneDrive 百度云
                #/usr/bin/rclone copy "$videoLocation" 你的rclone云盘名字:/文件夹/
                #/usr/local/bin/BaiduPCS-Go upload "$videoLocation$name" /
                cp -r "$videoLocation" /root/clouddrive/nutstore/CloudDrive/ali/Videos/bili/
                #发送通知
                #echo "$title" | mail -s "BFD：上传完成" $mailAddress #邮件方式
                #python3 /root/BiliFavoritesDownloader/sendemail.py --subject "<b>BFD：TASK DONE!</b>$title"
                #bark push
                omsg="Download Finished\n${videomessage}"
                #echo $omsg
                smsg=$(urlencode "${omsg}")
                #echo $smsg
                #curl https://api.day.app/{yourownkey}/$smsg?group=bili
                #echo $sendemailres
                #curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>BFD：上传完成</b>%0A%0A$title"
                break
            else
                if [ "$count" != "1" ]; then
                    count=$(($count + 1))
                    sleep 2
                else
                    rm -rf "$videoLocation"
                    #发送通知
                    #echo "$name" | mail -s "BFD：下载失败" $mailAddress  #邮件
                    #curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>BFD：下载失败</b>"
                    omsg="download failed:${title}"
                    smsg=$(urlencode "${omsg}")
                    #curl https://api.day.app/{yourownkey}/$smsg?group=bili
                    exit
                fi
            fi
        done & #如果是邮件通知，删除 & 和下面的内容(删到wait，fi保留)

        second="start"
        secondResult="" #$(curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="$second")
        subSecondResult="${secondResult#*message_id\":}"
        messageID=${subSecondResult%%,\"from*}

        ccount=0
        while true; do
            sleep 2
            text=$(tail -1 "${scriptLocation}${cur_sec}.txt")
            echo $text > "${scriptLocation}${cur_sec}${cur_sec}.txt"
            sed -i -e 's/\r/\n/g' "${scriptLocation}${cur_sec}${cur_sec}.txt"
            text=$(sed -n '$p' "${scriptLocation}${cur_sec}${cur_sec}.txt")
            result="" #$(curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/editMessageText" -d chat_id=$telegram_chat_id -d message_id=$messageID -d text="$text")
            mark=$(cat "${scriptLocation}${cur_sec}mark.txt")
            if [ $mark -eq 0 ]; then
                break
            fi
        done
        wait
        rm "${scriptLocation}${cur_sec}.txt"
        rm "${scriptLocation}${cur_sec}${cur_sec}.txt"
        rm "${scriptLocation}${cur_sec}mark.txt"
    else
        echo "duplicate task, skipping..."
        sleep 1
        #curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -d chat_id=$telegram_chat_id -d parse_mode=html -d text="<b>BFD：Cookies 文件失效，请更新后重试</b>%0A%0A$videomessage"
    fi
fi