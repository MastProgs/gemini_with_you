cd ./client

call flutter build web --web-renderer canvaskit --release --base-href /gemini_with_you/


cd ..

xcopy /e /y .\client\build\web\* .\docs\