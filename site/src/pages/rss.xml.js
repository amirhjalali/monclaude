import rss from "@astrojs/rss";
import { getCollection } from "astro:content";

export async function GET(context) {
  const guides = await getCollection("guides", ({ data }) => !data.draft);
  const prompts = await getCollection("prompts", ({ data }) => !data.draft);

  const items = [
    ...guides.map((g) => ({
      title: g.data.title,
      pubDate: g.data.pubDate,
      description: g.data.description,
      link: `/guides/${g.id}/`,
      categories: g.data.tags,
    })),
    ...prompts.map((p) => ({
      title: `Prompt: ${p.data.title}`,
      pubDate: p.data.pubDate,
      description: p.data.description,
      link: `/prompts/${p.id}/`,
      categories: p.data.tags,
    })),
  ].sort((a, b) => b.pubDate.getTime() - a.pubDate.getTime());

  return rss({
    title: "Clawed-Code",
    description: "Field notes on coding with Claude and other agents.",
    site: context.site,
    items,
  });
}
