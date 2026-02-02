const char* INDEX_HTML = R"rawliteral(
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SignLens Cam</title>
    <style>
        :root {
            --primary: #6366f1;
            --secondary: #a855f7;
            --bg: #0f172a;
            --surface: rgba(255, 255, 255, 0.05);
            --text: #f8fafc;
        }
        body {
            font-family: 'Segoe UI', sans-serif;
            background: var(--bg);
            color: var(--text);
            margin: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
            min-height: 100vh;
            background-image: linear-gradient(to bottom right, #0f172a, #1e1b4b);
        }
        .container {
            width: 90%;
            max-width: 600px;
            text-align: center;
            margin-top: 2rem;
        }
        h1 {
            background: linear-gradient(to right, #22d3ee, #c084fc);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }
        .status {
            display: inline-block;
            background: rgba(34, 197, 94, 0.2);
            color: #4ade80;
            padding: 0.25rem 0.75rem;
            border-radius: 999px;
            font-size: 0.875rem;
            margin-bottom: 1.5rem;
            border: 1px solid rgba(34, 197, 94, 0.3);
        }
        .card {
            background: var(--surface);
            border-radius: 24px;
            padding: 1rem;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.3);
        }
        img {
            width: 100%;
            border-radius: 16px;
            background: #000;
            display: block;
        }
        .controls {
            display: flex;
            justify-content: center;
            gap: 1rem;
            margin-top: 1.5rem;
        }
        .btn {
            background: linear-gradient(45deg, var(--primary), var(--secondary));
            border: none;
            padding: 0.75rem 1.5rem;
            border-radius: 12px;
            color: white;
            font-weight: 600;
            cursor: pointer;
            text-decoration: none;
            transition: transform 0.2s;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
        }
        .btn:hover {
            transform: translateY(-2px);
        }
        .btn-outline {
            background: transparent;
            border: 1px solid rgba(255,255,255,0.2);
        }
        .footer {
            margin-top: auto;
            padding: 2rem;
            font-size: 0.8rem;
            opacity: 0.6;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>SignLens Cam</h1>
        <div class="status">● En Ligne • ESP32-CAM</div>
        
        <div class="card">
            <img src="/stream" id="stream" alt="Camera Stream" onload="this.style.opacity=1" onerror="this.style.opacity=0.5">
        </div>

        <div class="controls">
            <button class="btn" onclick="location.reload()">Rafraîchir</button>
            <a href="/capture" target="_blank" class="btn btn-outline" style="color:white; display:inline-block">Photo</a>
        </div>
        
        <p style="margin-top: 1.5rem; opacity: 0.8;">
            Connectez cette caméra à l'application <strong>SignLens</strong> pour commencer la traduction.
        </p>
    </div>

    <div class="footer">
        IP: <script>document.write(window.location.hostname)</script>
    </div>
</body>
</html>
)rawliteral";
