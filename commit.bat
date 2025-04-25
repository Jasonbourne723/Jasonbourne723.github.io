

git config --global https.proxy 127.0.0.1:7890
git config --global http.proxy 127.0.0.1:7890


git add .
git commit -m "update"
git push

git config --global --unset http.proxy
git config --global --unset https.proxy
