# 1:user,2:command
exec_as() {
su "$1" -c "$2"
}
# 2:owner,3:permission,1:path,stdin:content
put_file() {
cat - > "$3"
chown "$1:$1" "$3"
chmod "$2" "$3"
}
# 1:owner,2:permission,3:path
make_dir() {
su "$1" -c "mkdir -p \"$3\""
chown "$1:$1" "$3"
chmod "$2" "$3"
}

# 1:owner, 2:origin_path, 3:symbol_path
make_link() {
ln -fs "$2" "$3"
chown -h "$1:$1" "$3"
}

# 1:owner, 2:permission, 3:origin_path, 4:symbol_path
copy_file() {
cp -f "$3" "$4"
chown "$1:$1" "$4"
chmod "$2" "$4"
}