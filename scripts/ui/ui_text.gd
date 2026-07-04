extends RefCounted
class_name UiText
## Утилиты текста UI. Главное — paginate(): режет длинное сообщение на страницы,
## которые гарантированно влезают в отведённый Label (иначе автоперенос «утекает»
## вниз и текст налезает на меню/статы — фикс наложения у торговцев и боссов).


static func wrapped_rows(line: String, chars_per_line: int) -> int:
    ## Оценка, сколько строк займёт line после автопереноса.
    return maxi(1, int(ceil(float(line.length()) / float(maxi(1, chars_per_line)))))


static func paginate(lines: Array, chars_per_line: int, max_rows: int) -> Array:
    ## [строки] -> [страница-текст, ...]; каждая страница ≤ max_rows строк с
    ## учётом автопереноса. Логические строки не режутся (кроме сверхдлинных,
    ## которые сами занимают > max_rows — такие уходят на отдельную страницу).
    var pages: Array = []
    var cur: Array = []
    var rows := 0
    for l in lines:
        var need := wrapped_rows(str(l), chars_per_line)
        if rows > 0 and rows + need > max_rows:
            pages.append("\n".join(cur))
            cur = []
            rows = 0
        cur.append(str(l))
        rows += need
    if not cur.is_empty():
        pages.append("\n".join(cur))
    if pages.is_empty():
        pages.append("")
    return pages
