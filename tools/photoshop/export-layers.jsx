#target photoshop

// 在 Photoshop 打开 PSD 后，通过「文件 > 脚本 > 浏览」运行。
// 将图层 1–8 分别与「图层 9」合成为八张 PNG；不修改原文档。
(function () {
    if (!app.documents.length) {
        alert("请先打开需要处理的 PSD 文件。");
        return;
    }

    var source = app.activeDocument;
    var oldDialogs = app.displayDialogs;
    var working = null;
    var output = null;
    var exported = 0;

    function normalized(name) {
        return String(name).replace(/[\s\u3000]+/g, "").toLowerCase();
    }

    function collect(container, path, label, result) {
        for (var i = 0; i < container.layers.length; i++) {
            var layer = container.layers[i];
            var current = path.concat([i]);
            var description = label + "/" + layer.name;
            result.push({name: layer.name, path: current, label: description});
            if (layer.typename === "LayerSet") {
                collect(layer, current, description, result);
            }
        }
    }

    function selectUnique(records, predicate, label) {
        var matches = [];
        for (var i = 0; i < records.length; i++) {
            if (predicate(normalized(records[i].name))) {
                matches.push(records[i]);
            }
        }
        if (!matches.length) {
            throw new Error("找不到「" + label + "」。请检查图层名称。");
        }
        if (matches.length !== 1) {
            var names = [];
            for (var j = 0; j < matches.length; j++) names.push(matches[j].label);
            throw new Error("「" + label + "」匹配到多个图层，无法确定目标：\n" + names.join("\n"));
        }
        return matches[0];
    }

    function prefixOf(a, b) {
        if (a.length > b.length) return false;
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false;
        }
        return true;
    }

    function isolate(container, path, a, b) {
        for (var i = 0; i < container.layers.length; i++) {
            var layer = container.layers[i];
            var current = path.concat([i]);
            var isA = prefixOf(current, a);
            var isB = prefixOf(current, b);
            layer.visible = isA || isB;
            if (layer.visible && layer.typename === "LayerSet") {
                // 目标为整个组时，保留该组内部原有的可见性。
                var isTarget = (isA && current.length === a.length) ||
                    (isB && current.length === b.length);
                if (!isTarget) isolate(layer, current, a, b);
            }
        }
    }

    function pad(number) { return number < 10 ? "0" + number : String(number); }

    function createOutput(parent) {
        var now = new Date();
        var stamp = now.getFullYear() + pad(now.getMonth() + 1) + pad(now.getDate()) +
            "_" + pad(now.getHours()) + pad(now.getMinutes()) + pad(now.getSeconds());
        var base = parent.fsName + "/layer9_exports_" + stamp;
        var folder = new Folder(base);
        var suffix = 1;
        while (folder.exists) folder = new Folder(base + "_" + suffix++);
        if (!folder.create()) throw new Error("无法创建导出文件夹：\n" + folder.fsName);
        return folder;
    }

    try {
        if (source.mode !== DocumentMode.RGB && source.mode !== DocumentMode.GRAYSCALE) {
            throw new Error("脚本支持 RGB 或灰度文档。请在 PS 中复制文档，将副本转换为 RGB 后再运行。");
        }
        if (source.bitsPerChannel !== BitsPerChannelType.EIGHT &&
                source.bitsPerChannel !== BitsPerChannelType.SIXTEEN) {
            throw new Error("PNG 导出需要 8 位或 16 位文档。请在 PS 中复制文档并调整副本后再运行。");
        }

        var records = [];
        collect(source, [], "", records);
        var common = selectUnique(records, function (name) { return name === normalized("图层 9"); }, "图层 9");
        var numbered = [];
        for (var number = 1; number <= 8; number++) {
            var matcher = new RegExp("^(?:图层|layer)?0*" + number + "$");
            var match = selectUnique(records, function (name) { return matcher.test(name); }, "图层 " + number);
            if (prefixOf(match.path, common.path) || prefixOf(common.path, match.path)) {
                throw new Error("「图层 " + number + "」和「图层 9」存在包含关系。请将两者整理为独立图层或独立组后运行。");
            }
            numbered.push(match);
        }

        var parent = Folder.selectDialog("选择保存位置：将新建子文件夹，导出 8 张 PNG（原画布大小）");
        if (!parent) return;
        output = createOutput(parent);
        app.displayDialogs = DialogModes.NO;

        for (var index = 0; index < numbered.length; index++) {
            try {
                app.activeDocument = source;
                working = source.duplicate("图层 9_导出副本_" + (index + 1), false);
                app.activeDocument = working;
                isolate(working, [], numbered[index].path, common.path);

                var options = new PNGSaveOptions();
                options.interlaced = false;
                // PNG 自动合成可见图层；保留画布尺寸和剩余的透明区域。
                var file = new File(output.fsName + "/图层 " + (index + 1) + "_图层 9.png");
                working.saveAs(file, options, true, Extension.LOWERCASE);
                if (!file.exists || file.length === 0) {
                    throw new Error("导出文件未成功写入：\n" + file.fsName);
                }
                exported++;
            } finally {
                if (working !== null) {
                    working.close(SaveOptions.DONOTSAVECHANGES);
                    working = null;
                }
            }
        }
        alert("已导出 " + exported + " 张 PNG，原 PSD 未修改。\n\n保存位置：\n" + output.fsName);
    } catch (error) {
        var message = "导出停止：" + error.message;
        if (output !== null) message += "\n\n已导出 " + exported + " 张，保存在：\n" + output.fsName;
        alert(message);
    } finally {
        if (working !== null) {
            try { working.close(SaveOptions.DONOTSAVECHANGES); } catch (ignored) {}
        }
        app.displayDialogs = oldDialogs;
        app.activeDocument = source;
    }
}());
