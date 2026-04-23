#!/bin/bash
set -e

# ShinobiPets + NanoClaw Agent Setup
# Run as: bash <(curl -sL https://raw.githubusercontent.com/kyooosukedn/nanoclaw/main/scripts/setup-vps.sh)
# Or paste this entire script into your VPS terminal

echo "=== ShinobiPets NanoClaw Agent Setup ==="

# 1. System basics
apt-get update && apt-get install -y git curl python3 sqlite3

# 2. Docker (if not installed)
if ! command -v docker &>/dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker && systemctl start docker
fi

# 3. Node.js 22
if ! command -v node &>/dev/null; then
  echo "Installing Node.js 22..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi

echo "node: $(node -v), docker: $(docker --version)"

# 4. Clone NanoClaw (your fork)
cd /opt
if [ -d nanoclaw ]; then
  cd nanoclaw && git pull
else
  git clone https://github.com/kyooosukedn/nanoclaw.git
  cd nanoclaw
fi

# 5. Install deps
npm install

# 6. Build agent container
echo "Building agent container (this takes a few minutes)..."
docker build -t nanoclaw-agent:latest -f container/Dockerfile container/

# 7. Clone ShinobiPets (agent will work on this)
cd /opt
if [ -d shinobipets ]; then
  cd shinobipets && git pull
else
  git clone https://github.com/kyooosukedn/shinobipets.git
fi

# 8. Setup NanoClaw config
cd /opt/nanoclaw
mkdir -p data/sessions groups/shinobipets store

# .env
cat > .env << 'EOF'
ASSISTANT_NAME=ShinobiBot
TZ=UTC
EOF

# Group CLAUDE.md (agent instructions)
cat > groups/shinobipets/CLAUDE.md << 'GROUPEOF'
# ShinobiPets Development Agent

You are ShinobiBot, a development agent for the ShinobiPets project.

## Project
- **Repo**: /workspace/extra/shinobipets
- **Tech**: React 19 + Three.js (R3F) + Zustand + TypeScript + Vite + Supabase
- **Live**: https://shinobipets.vercel.app
- **Version**: 0.4.0

## Your Job
When asked to work on ShinobiPets:
1. Read the codebase at /workspace/extra/shinobipets
2. Make changes following the project's patterns (Zustand stores, EventBus, scene components)
3. Run `npm run build` in /workspace/extra/shinobipets to verify no errors
4. Commit with semantic messages
5. Push to origin main

## Current Roadmap (v0.5)
- Dungeon exploration (room-to-room navigation)
- Pet evolution visuals (model changes between stages)
- Battle arena themes (element-specific backgrounds)
- Sound design pass (unique SFX per element)
- PWA + offline play

## Key Patterns
- Scenes in `src/scenes/`, registered in `src/App.tsx`
- Stores in `src/stores/` (Zustand)
- Systems in `src/systems/` (pure logic)
- Data in `src/data/` (static definitions)
- 3D models in `src/components/three/`
- UI in `src/components/ui/`
- EventBus for cross-system communication

## Style
- One commit per logical change
- Test in browser before pushing
- Keep caveman mode: terse, no fluff
GROUPEOF

# 9. Init database
python3 -c "
import sqlite3, os
db = sqlite3.connect('/opt/nanoclaw/store/messages.db')
db.execute('DROP TABLE IF EXISTS registered_groups')
db.execute('''CREATE TABLE registered_groups (
    jid TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    folder TEXT DEFAULT '',
    is_main INTEGER DEFAULT 0
)''')
db.execute('INSERT INTO registered_groups (jid, name, folder, is_main) VALUES (?, ?, ?, ?)',
    ('main@local', 'main', 'groups/main', 1))
db.execute('INSERT INTO registered_groups (jid, name, folder, is_main) VALUES (?, ?, ?, ?)',
    ('shinobipets@local', 'shinobipets', 'groups/shinobipets', 0))
db.commit()
db.close()
print('DB initialized')
"

# 10. Patch claw to mount ShinobiPets + host .claude
mkdir -p /opt/nanoclaw/scripts
cp /opt/nanoclaw/.claude/skills/claw/scripts/claw /opt/nanoclaw/scripts/claw 2>/dev/null || true
if [ -f /opt/nanoclaw/scripts/claw ]; then
  # Add ShinobiPets mount
  sed -i '/if agent_runner_src.exists/,/return mounts/ {
    /return mounts/i\    # Mount ShinobiPets project
    sp_dir = Path("/opt/shinobipets")
    if sp_dir.exists():
        mounts.append((str(sp_dir), "/workspace/extra/shinobipets", False))
  }' /opt/nanoclaw/scripts/claw 2>/dev/null || true
  chmod +x /opt/nanoclaw/scripts/claw
fi

# 11. Install claw CLI
ln -sf /opt/nanoclaw/scripts/claw /usr/local/bin/claw 2>/dev/null || true

# 12. Build NanoClaw
cd /opt/nanoclaw && npm run build

# 13. Test
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Test with:"
echo "  claw --list-groups"
echo "  claw -g shinobipets 'List files in /workspace/extra/shinobipets/src/scenes/'"
echo ""
echo "NOTE: The agent needs Claude auth. From your LOCAL machine run:"
echo "  ssh -R /home/root/.claude:/home/YOU/.claude root@142.93.101.31"
echo "  Or: set ANTHROPIC_API_KEY=sk-... in /opt/nanoclaw/.env"
echo ""
echo "To run NanoClaw as a daemon:"
echo "  cd /opt/nanoclaw && npm run dev &"
