import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const guides = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/guides" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.string()).default([]),
    author: z.string().default("Amir Jalali"),
    draft: z.boolean().default(false),
    order: z.number().default(100),
  }),
});

const tools = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/tools" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    repo: z.string().url().optional(),
    homepage: z.string().url().optional(),
    tags: z.array(z.string()).default([]),
    featured: z.boolean().default(false),
    draft: z.boolean().default(false),
  }),
});

const prompts = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/prompts" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    agent: z.enum(["claude-code", "claude-api", "cursor", "other", "any"]).default("any"),
    draft: z.boolean().default(false),
  }),
});

export const collections = { guides, tools, prompts };
