# CONTRIBUTING

## Basic: export patch file

如不能熟练使用 Git，建议通过导出 diff patch 的方式提交变更内容。

注意：在 Windows 平台导出 patch 时，请务必确认使用 PowerShell (Core) v7.4+ ！


```powershell
host

# If version <= 7.3, upgrade through winget
winget upgrade Microsoft.PowerShell
```

1. 通过 `git show` 查看提交内容（可先通过 `git log` 查看 commit hash），然后 `git diff > <file]`

```
git show COMMIT_HASH
```

2. 修改完成后，无须提交，直接导出变更内容到 `mypatch.patch` 文件

```
git add --all
git diff --cached > mypatch.patch
```
