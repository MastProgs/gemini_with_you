cd ./client

call flutter build web --web-renderer canvaskit --release


cd ..

xcopy /e /y .\client\build\web\* .\docs\