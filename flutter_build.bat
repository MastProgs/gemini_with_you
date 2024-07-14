cd ./client

call flutter build web --web-renderer html --release


cd ..

xcopy /e /y .\client\build\web\* .\docs\