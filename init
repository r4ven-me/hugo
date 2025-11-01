<%*
function translit(str) {
    const map = {
        'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ё':'yo','ж':'zh',
        'з':'z','и':'i','й':'y','к':'k','л':'l','м':'m','н':'n','о':'o',
        'п':'p','р':'r','с':'s','т':'t','у':'u','ф':'f','х':'h','ц':'c',
        'ч':'ch','ш':'sh','щ':'shch','ъ':'','ы':'y','ь':'','э':'e','ю':'yu','я':'ya'
    };
    return str.toLowerCase()
        .trim()
        .replace(/\s+/g, 
'-')             // spaces → hyphens
        .split('')
        .map(c => map[c] ?? c)
        .join('')
        .replace(/[^a-z0-9\-_.]/g, '')
        .replace(/[-]+/g, '-')
        .replace(/^-+|-+$/g, '');
}

function getAllFolders() {
    const out = [];
    const root = app.vault.getRoot();
    function walk(folder) {
        out.push(folder.path);
        if (!folder.children) return;
        folder.children.forEach(c => {
            if (Array.isArray(c.children)) walk(c);
        });
    }
    walk(root);
    return out;
}

try {
    const folders = getAllFolders();
    if (!folders || folders.length === 0) {
        new Notice("Failed to get folder list in vault.");
        return;
    }

    // select base folder (e.g., content/posts/linux)
    const basePath = await tp.system.suggester(folders, folders);
    if (!basePath) {
        new Notice("Folder selection cancelled.");
        return;
    }

    const today = tp.date.now("YYYY-MM-DD");
    const rusName = await tp.system.prompt("Enter title (in Russian):");
    if (!rusName) {
        new Notice("No title entered - cancelled.");
        return;
    }

    const slug = translit(rusName) || "untitled";
    const folderName = `${today}-${slug}`;
    const finalPath = `${basePath}/${folderName}`;

    // create new folder for post
    await app.vault.createFolder(finalPath).catch(()=>{});

    // category - last element of basePath
    const categoryName = basePath.split("/").pop();

    // frontmatter
    const frontmatter = 
`---
draft: true
title: ${JSON.stringify(rusName)}
date: ${today}
lastmod:
author: Ivan Cherniy
toc: false
slug: ${slug}
url: /${categoryName}/${slug}
aliases:
categories:
  - ${categoryName}
tags:
  - raven
cover: cover.jpg
description: Post description.
---

## Greeting

## Article content

## Conclusion
`;

    // create index.md
    const targetPath = `${finalPath}/index.md`;
    const existing = app.vault.getAbstractFileByPath(targetPath);
    if (existing) {
        new Notice(`⚠️ Already exists: ${targetPath}`);
    } else {
        await app.vault.create(targetPath, frontmatter);
        new Notice(`✅ Created: ${targetPath}`);
    }

} catch (err) {
    new Notice("Script error: " + (err?.message ?? String(err)));
    console.error(err);
}
%>
