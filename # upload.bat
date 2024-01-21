git add . :!*.ini
git status
git commit -m "uploaded by script"

git push -u origin master
git push -u origin_gitlab master
pause