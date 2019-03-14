---
layout: post
title:  "XML sitemaps in React with Typescript"
date:   2019-03-14 09:25:00
categories: typescript
---

I maintain the [Repositive website](https://repositive.io) which uses React for the frontend and a server that supports server side rendering for the speed and SEO benefits of SSR. I'm currently in the process of porting it over to Typescript which is kickass, but the type checker kept borking on the XML tags used in the sitemap component. What follows is a quick "note to self" on how to fix that error. There might be _much_ better solutions out there, but this is the one that worked for me.

A slimmed down sitemap component is listed below. It's rendered on the NodeJS server so search engines _et al_ can pick it up without having to execute any JS.

```typescript
const staticRoutes = [ /* snip */ ];

class Sitemap extends React.Component {
  render(): any {
    const baseUrl = "https://foobar.io";
    const now = new Date().toISOString();

    const staticRoutes = routes
      .filter((r) => r.sitemap.show)
      .map((r) => {
        return (
          <url key={r.path}>
            <loc>{`${baseUrl}${r.path}`}</loc>
            <lastmod>{now}</lastmod>
            <priority>{r.sitemap.priority}</priority>
          </url>
        );
      });

    return (
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
        {staticRoutes}
      </urlset>
    );
  }
}
```

Typescript spews error `TS2339` when it encounters the lowercase `<url>`, `<urlset>`, etc tags. The solution I found [here](https://github.com/Microsoft/TypeScript/issues/15449#issuecomment-385959396) is to add this to the top of the file you want to use custom elements in:

```typescript
declare global {
  namespace JSX {
    interface IntrinsicElements {
      url: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
      loc: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
      lastmod: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
      priority: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
      urlset: React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>;
    }
  }
}
```

This works for Typescript 3.3.3. As far as I know, this doesn't blow away React's normal DOM element type checking. Naturally you'll have to add any other tags you use to the list above. This fixes the Typescript errors, so now I can continue on my merry Typescripty way.
