# CCPM.Helios Installation Guide

## Smart Installation (Recommended)

CCPM.Helios includes **smart installation** that preserves existing PRDs and Epics during installation or upgrades.

### Quick Start

```bash
# Clone repository and run smart installer
git clone https://github.com/good-night-oppie/ccpm.helios.git
cd ccpm.helios
./scripts/smart-install.sh install /path/to/your/project true
```

### Installation Options

#### Option 1: Preserve Existing Content (Default)
```bash
./scripts/smart-install.sh install . true
```
- ✅ Preserves existing PRDs and Epics
- ✅ Creates automatic backups
- ✅ Merges new functionality with existing content
- ✅ Migrates from legacy `.claude` structure to `ccpm`

#### Option 2: Fresh Installation
```bash
./scripts/smart-install.sh install . false
```
- ⚠️ Replaces existing PRDs and Epics
- ✅ Creates backups before replacement
- ✅ Installs clean CCPM structure

#### Option 3: Content Detection Only
```bash
./scripts/smart-install.sh detect
```
- 🔍 Shows what content exists without installing
- 📊 Reports on PRDs, Epics, and legacy structures
- 💡 Helps you decide on installation approach

### Migration Scenarios

#### Scenario 1: New Project (Empty Directory)
```bash
./scripts/smart-install.sh install
# Result: Clean CCPM installation with Oracle integration
```

#### Scenario 2: Existing CCPM Project with Content
```bash
./scripts/smart-install.sh detect  # Check what exists
./scripts/smart-install.sh install . true  # Preserve content
# Result: Upgrades CCMP while preserving your PRDs/Epics
```

#### Scenario 3: Legacy .claude Structure
```bash
./scripts/smart-install.sh install . true
# Result: Migrates .claude -> ccpm structure while preserving content
```

## Legacy Installation Methods

### Remote Installation (Simple)

#### Unix/Linux/macOS
```bash
curl -sSL https://automaze.io/ccpm/install | bash
# OR
wget -qO- https://automaze.io/ccpm/install | bash
```

#### Windows (PowerShell)
```powershell
iwr -useb https://automaze.io/ccpm/install | iex
```

### Direct Git Clone (No Preservation)
```bash
git clone https://github.com/good-night-oppie/ccpm.helios.git . && rm -rf .git
```

⚠️ **Warning**: Direct cloning will overwrite existing content without backup.

## Done Oracle Integration Setup

CCPM includes **Done Oracle** integration for AI-powered task completion verification. To enable Oracle functionality:

### 1. Prerequisites
- Node.js 18+ installed
- Done Oracle service running at `http://localhost:3000`
- Install Done Oracle from: https://github.com/good-night-Oppie/oppie-done-oracle

### 2. Done Oracle Service Setup

```bash
# Install Done Oracle from source:
git clone https://github.com/good-night-Oppie/oppie-done-oracle.git
cd oppie-done-oracle
# Follow installation instructions in the repository

# If you have Done Oracle installed separately:
done-oracle --port 3000 --health-check

# Or via Docker:
docker run -p 3000:3000 done-oracle:latest
```

### 3. Verify Integration

```bash
# Check Oracle service health
curl -s http://localhost:3000/health

# Test Oracle API
curl -s -X POST http://localhost:3000/api/bridge/evaluate \
  -H "Content-Type: application/json" \
  -d '{"repo": ".", "context": {"task": "test", "type": "health_check"}}'
```

### 4. Oracle Commands Usage

Once setup is complete, you can use Oracle commands in your CCPM workflow:

```bash
# Check all tasks in an epic for Oracle verification
/pm:oracle-status <epic-name>

# Manually verify a specific task
/pm:oracle-verify <task-number>
```

**Note**: Oracle commands require the Done Oracle service to be running. If the service is unavailable, commands will fail gracefully with clear error messages.

## Backup and Recovery

CCPM.Helios automatically creates backups during installation to protect your content.

### Automatic Backups

Every installation creates timestamped backups:
```bash
.ccpm-backup-20231201-120000/   # Smart installation backup
.pre-restore-backup-20231201-120000/  # Pre-restoration backup
```

### Manual Backup Management

#### List Available Backups
```bash
./scripts/restore-backup.sh list
```

#### Restore from Backup
```bash
# Interactive restoration (with confirmation)
./scripts/restore-backup.sh restore .ccpm-backup-20231201-120000

# Automated restoration (no confirmation)
./scripts/restore-backup.sh restore .ccpm-backup-20231201-120000 true
```

#### Clean Old Backups
```bash
# Remove backups older than 30 days (default)
./scripts/restore-backup.sh clean

# Remove backups older than 7 days
./scripts/restore-backup.sh clean . 7
```

### Recovery Scenarios

#### Scenario 1: Installation Went Wrong
```bash
# Find latest backup
./scripts/restore-backup.sh list

# Restore from latest backup
./scripts/restore-backup.sh restore .ccmp-backup-YYYYMMDD-HHMMSS
```

#### Scenario 2: Accidental Content Loss
```bash
# Check what can be restored
./scripts/restore-backup.sh list

# Restore specific content
./scripts/restore-backup.sh restore .pre-restore-backup-YYYYMMDD-HHMMSS
```

#### Scenario 3: Migration Rollback
```bash
# Rollback using smart installer
./scripts/smart-install.sh rollback .ccpm-backup-YYYYMMDD-HHMMSS
```

### Backup Contents

Backups preserve:
- ✅ **PRDs**: All Product Requirements Documents
- ✅ **Epics**: All Epic planning documents and task files
- ✅ **Configuration**: package.json, README.md modifications
- ✅ **Legacy Structure**: Original `.claude` directory if migrated

### Best Practices

1. **Always run detection first**: `./scripts/smart-install.sh detect`
2. **Keep recent backups**: Don't clean backups immediately after installation
3. **Test restoration**: Verify backups work before relying on them
4. **Document custom changes**: Keep notes on any manual modifications
