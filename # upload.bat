git add . :!*.ini
git status
set /p Input=Enter commit message:
git commit -m "%Input%"

git push -u origin master
git push -u origin_gitlab master
pause