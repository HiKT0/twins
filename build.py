import os

# files_to_pack = []
# for root, sub_dirs, files in os.walk("./src"):
#     for f in files:
#         files_to_pack.append((root.replace("\\", "/") + "/" + f)[6:])

f = open("./build_files.txt")
files_to_pack = f.readlines()
f.close()

out = "local fs = require(\"filesystem\")\nlocal pkg = { "
for f in files_to_pack:
    print("packing file: " + f)
    file = open(f.replace("\n", ""), encoding="utf-8")
    file_content = file.read()

    while True:
        start = file_content.find("--[[")
        if start == -1:
            break
        end = file_content.find("]]", start)
        file_content = file_content[:start] + file_content[end+2:]
    
    while True:
        start = file_content.find("--")
        if start == -1:
            break
        end = file_content.find("\n", start)
        print(f"Удаление комментария: {start}:{end}")
        if end == -1:
            file_content = file_content[:start]
        else:
            file_content = file_content[:start] + file_content[end:]
    out += "[\"/lib/twins/" + f.replace("\n", "") + "\"]=\"" + file_content.replace("\\", "\\\\").replace("\\\\n", "\\n").replace("\"", "\\\"").replace("'", "\\'") + "\","
    file.close()

f = open("./install.lua", "w", encoding="utf-8")
f.write(out[:-1] + "}\n")
f.write(
"""
for k, v in pairs(pkg) do
    local dir = fs.path(k)
    if (not fs.isDirectory(dir)) or (not fs.exists(dir)) then
        print("Создание папки: "..dir)
        fs.makeDirectory(dir)
    end
    print("Распаковка: "..k)
    local f, e = io.open(k, "w")
    if not f then error(e) end
    f:write(v)
    f:flush()
    f:close()
end
"""
)
f.close()
os.system("pause")