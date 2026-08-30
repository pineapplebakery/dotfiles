_python_m_module_complete() {
  # python -m <ここ> のときだけ
  [[ "${words[CURRENT-1]}" == "-m" ]] || return 1

  local py="${words[CURRENT-2]:t}"
  case "$py" in
    python|python3|python3.*) ;;
    *) return 1 ;;
  esac

  local -a modules
  local f mod

  # カレントディレクトリ以下の .py を全部 Python module 名に変換
  for f in **/*.py(N); do
    [[ "$f" == */__pycache__/* ]] && continue

    if [[ "${f:t}" == "__init__.py" ]]; then
      # foo/bar/__init__.py -> foo.bar
      mod="${f:h}"
    else
      # foo/bar/baz.py -> foo.bar.baz
      mod="${f%.py}"
    fi

    mod="${mod#./}"
    mod="${mod//\//.}"

    modules+=("$mod")
  done

  (( ${#modules} )) || return 1

  _multi_parts . modules
}

zstyle ':completion:*' completer _python_m_module_complete _complete
