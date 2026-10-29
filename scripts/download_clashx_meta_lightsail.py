#!/usr/bin/env python3
"""Download pinned ClashX Meta v1.4.47 via 4 HTTPS Range workers.

Public, no-login client downloader. Retrieves the official release archive.
No changes to DNS, system proxy, macOS settings, or AWS infrastructure.
"""
import argparse
import concurrent.futures
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time
import zipfile

URL = "https://ioant.com:18443/ClashX.Meta.zip"
RESOLVE = "ioant.com:18443:13.213.140.184"
SIZE = 89683343
EXPECTED_SHA256 = "cc76aa2e561df8e127147324c60a787522001aa0f71ebe9b394ea8e23d809e40"
CHUNK_SIZE = 1024 * 1024
WORKERS = 4
ATTEMPTS = 5
OUT = Path.home() / "Downloads" / "ClashX.Meta-Lightsail.zip"
PARTS = Path.home() / "Downloads" / ".ClashX.Meta-Lightsail.parts"


def chunks():
    return [(idx, start, min(SIZE - 1, start + CHUNK_SIZE - 1))
            for idx, start in enumerate(range(0, SIZE, CHUNK_SIZE))]


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for part in iter(lambda: stream.read(CHUNK_SIZE), b""):
            h.update(part)
    return h.hexdigest()


def valid_zip(path):
    try:
        with zipfile.ZipFile(path) as archive:
            return bool(archive.infolist()) and archive.testzip() is None
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile, RuntimeError):
        return False


def has_expected_content_range(raw_headers, start, end):
    raw = raw_headers.decode("iso-8859-1", errors="replace")
    blocks = re.split(r"\r?\n\r?\n", raw.strip())
    final = [block for block in blocks if block.lower().startswith("http/")]
    if not final:
        return False
    lines = final[-1].splitlines()
    if not re.match(r"^HTTP/\S+\s+206(?:\s|$)", lines[0], re.I):
        return False
    expected = f"bytes {start}-{end}/{SIZE}"
    return any(line.lower().startswith("content-range:") and
               line.split(":", 1)[1].strip() == expected for line in lines[1:])


def fetch(item):
    index, start, end = item
    correct_len = end - start + 1
    final = PARTS / f"{index:03d}.chunk"
    if final.exists():
        if final.stat().st_size == correct_len:
            return index, True
        final.unlink()
    temporary = PARTS / f"{index:03d}.incomplete"
    headers = PARTS / f"{index:03d}.headers"
    for attempt in range(1, ATTEMPTS + 1):
        temporary.unlink(missing_ok=True)
        headers.unlink(missing_ok=True)
        args = [
            "curl", "-q", "-4", "--http1.1", "--noproxy", "*",
            "--proto", "=https", "--tlsv1.2", "--fail", "--silent",
            "--show-error", "--connect-timeout", "12", "--max-time", "120",
            "--speed-limit", "2048", "--speed-time", "45", "--retry", "0",
            "--resolve", RESOLVE, "--range", f"{start}-{end}",
            "--dump-header", str(headers), "--output", str(temporary),
            "--write-out", "%{http_code}", URL,
        ]
        try:
            p = subprocess.run(args, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, timeout=130, check=False)
            ok = (p.returncode == 0 and p.stdout.strip() == b"206" and
                  temporary.is_file() and temporary.stat().st_size == correct_len and
                  headers.is_file() and
                  has_expected_content_range(headers.read_bytes(), start, end))
        except (OSError, subprocess.TimeoutExpired):
            ok = False
        if ok:
            os.replace(temporary, final)
            headers.unlink(missing_ok=True)
            return index, False
        temporary.unlink(missing_ok=True)
        headers.unlink(missing_ok=True)
        if attempt < ATTEMPTS:
            time.sleep(min(3 * attempt, 10))
    raise RuntimeError(f"分块 {index + 1}/{len(chunks())} 下载失败；已成功分块仍保留，可重新执行")


def download():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if (OUT.exists() and OUT.stat().st_size == SIZE and
            digest(OUT) == EXPECTED_SHA256 and valid_zip(OUT)):
        print("ZIP_SHA256_PASS: 已有完整安装包，跳过下载", flush=True)
        print("FILE=" + str(OUT), flush=True)
        return
    PARTS.mkdir(mode=0o700, exist_ok=True)
    items = chunks()
    print(f"四路并行下载 | {len(items)} 个分块 | 断点保留 | TLS 证书验证开启", flush=True)
    begun = time.monotonic()
    completed = 0
    reused = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futures = [pool.submit(fetch, item) for item in items]
        for future in concurrent.futures.as_completed(futures):
            _, from_cache = future.result()
            completed += 1
            reused += bool(from_cache)
            if completed % 5 == 0 or completed == len(items):
                print(f"进度: {completed}/{len(items)} 块 ({completed / len(items):.0%}) | 已复用 {reused} 块", flush=True)
    temporary = OUT.with_name(OUT.name + ".assembling")
    digest_builder = hashlib.sha256()
    copied = 0
    with temporary.open("wb") as output:
        for index, _, _ in items:
            part = PARTS / f"{index:03d}.chunk"
            with part.open("rb") as source:
                for segment in iter(lambda: source.read(CHUNK_SIZE), b""):
                    output.write(segment)
                    digest_builder.update(segment)
                    copied += len(segment)
    if (copied != SIZE or digest_builder.hexdigest() != EXPECTED_SHA256 or
            not valid_zip(temporary)):
        temporary.unlink(missing_ok=True)
        raise RuntimeError("大小、SHA-256 或 ZIP 完整性不匹配；不会安装，也不清除已下载分块")
    os.replace(temporary, OUT)
    shutil.rmtree(PARTS)
    print("ZIP_SHA256_PASS", flush=True)
    print("ZIP_INTEGRITY_PASS", flush=True)
    print("FILE=" + str(OUT), flush=True)
    print(f"已验证完整安装包；总耗时 {time.monotonic() - begun:.1f}s", flush=True)


def self_test():
    items = chunks()
    assert items[0] == (0, 0, CHUNK_SIZE - 1)
    assert items[-1][2] == SIZE - 1
    assert sum(end - start + 1 for _, start, end in items) == SIZE
    assert len(items) == 86
    good = f"HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 0-15/{SIZE}\r\n\r\n".encode()
    bad = f"HTTP/1.1 200 OK\r\nContent-Range: bytes 0-15/{SIZE}\r\n\r\n".encode()
    assert has_expected_content_range(good, 0, 15)
    assert not has_expected_content_range(bad, 0, 15)
    with tempfile.TemporaryDirectory() as tmp:
        sample = Path(tmp) / "fixture.zip"
        with zipfile.ZipFile(sample, "w") as archive:
            archive.writestr("a.txt", "test")
        assert valid_zip(sample)
        sample.write_bytes(b"not zip")
        assert not valid_zip(sample)
    print("CLASHX_PARALLEL_SELF_TEST_PASS")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", nargs="?", choices=("download",), default="download")
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    try:
        (self_test if arguments.self_test else download)()
    except (RuntimeError, OSError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        sys.exit(2)
