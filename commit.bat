
echo "设置代理"

git config --global https.proxy 127.0.0.1:7890
git config --global http.proxy 127.0.0.1:7890

echo "设置代理完成"
echo "开始提交代码"
git add .
git commit -m "update"
git push
echo "提交代码完成"
echo "取消代理"
git config --global --unset http.proxy
git config --global --unset https.proxy
echo "取消代理完成"