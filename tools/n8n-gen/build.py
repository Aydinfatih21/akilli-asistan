"""Tüm n8n workflow JSON'larını üretir: python tools/n8n-gen/build.py
Çıktı: n8n/workflows/*.json (credential kimliği yer tutucudur; içe aktarmadan önce
scripts/set-credential-id.ps1 ile kendi credential kimliğinizi yazın)."""
import os
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.normpath(os.path.join(here, "..", "..", "n8n", "workflows"))
for script in ("gen_mongo.py", "gen_mongo2.py"):
    subprocess.run([sys.executable, os.path.join(here, script), out], check=True, cwd=here)
print("Workflow'lar üretildi →", out)
