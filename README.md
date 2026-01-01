# VESC based one wheeled PEV configs

* My configs or configs I backed up for friends.
* Feel free to take a peak. Keep in mind that I'm no tune wizard. [Zdeněk](https://www.instagram.com/louckazdenekjr/) is. ;)
* Configs may come and go, change, may not be intended for use with Floatwheel, be completely broken etc.

GL&HF. Float on.

---

## Secrets Management

This repo uses automated secrets sanitization to keep WiFi passwords, TCP hub passwords, and BLE PINs out of git history.

### Initial Setup

**1. Create your secrets file:**
```bash
cp .secrets.example .secrets
chmod 600 .secrets
```

**2. Edit `.secrets` with your actual passwords:**
```bash
nano .secrets
# OR
vim .secrets
```

**3. Install the pre-commit hook:**
```bash
# Create hooks directory if needed
mkdir -p .git/hooks

# Create symlink to sanitize script
ln -sf ../../scripts/sanitize-secrets.sh .git/hooks/pre-commit

# Verify installation
ls -l .git/hooks/pre-commit
```

**4. Test it out:**
```bash
# Test the hook
git commit --allow-empty -m "Test secrets sanitization"
# You should see: "[SANITIZE] Loaded N secret(s) from .secrets"
```

### Daily Workflow

**Making changes to configs:**
```bash
# 1. Restore secrets to your working files
./scripts/restore-secrets.sh

# 2. Make your changes to XML files
# (edit, test, tune, etc.)

# 3. Commit (secrets are auto-sanitized by pre-commit hook)
git commit -m "Update configuration"

# 4. After commit, restore again for testing/use
./scripts/restore-secrets.sh
```

**After pulling changes:**
```bash
git pull
./scripts/restore-secrets.sh
```

### How It Works

- **`.secrets` file**: Contains your actual passwords (one per line, gitignored)
- **Pre-commit hook**: Automatically replaces passwords with placeholders like `REDACTED-LINE-1`, `REDACTED-LINE-2`, etc.
- **Restore script**: Brings back your real passwords to working files (not committed)
- **Line numbers matter**: Line 1 in `.secrets` becomes placeholder 1, line 2 becomes placeholder 2, etc.

### Troubleshooting

**Problem: "ERROR: Missing .secrets file"**
- **Solution**: Create `.secrets` file following setup instructions above

**Problem: Wrong password got replaced**
- **Solution**: Check line numbering in `.secrets` - empty lines and `#` comments are skipped

**Problem: Need to add a new secret**
- **Solution**: Add it to the end of `.secrets` (becomes next REDACTED-LINE-N)

**Problem: Hook not running on commit**
- **Solution**: Verify symlink exists: `ls -l .git/hooks/pre-commit`
- If missing, run step 3 from Initial Setup again

**Problem: Want to commit without sanitization (emergency)**
- **Solution**: Use `git commit --no-verify` (but really, don't do this!)
