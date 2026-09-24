export type ThemeId = "dark" | "light" | "brown" | "forest" | "ocean" | "sunset";

export type Theme = {
  id: ThemeId;
  name: string;
  description: string;
  preview: string[]; // 3 colors for preview
  accent: string;
};

export const themes: Theme[] = [
  {
    id: "dark",
    name: "Midnight",
    description: "Atual • escuro com roxo",
    preview: ["#09090b", "#18181b", "#7c3aed"],
    accent: "violet",
  },
  {
    id: "light",
    name: "Light",
    description: "Branco • limpo e claro",
    preview: ["#ffffff", "#f4f4f5", "#7c3aed"],
    accent: "violet",
  },
  {
    id: "brown",
    name: "Desert",
    description: "Marrom • madeira rústica",
    preview: ["#1c1917", "#292524", "#d97706"],
    accent: "amber",
  },
  {
    id: "forest",
    name: "Forest",
    description: "Verde • natureza profunda",
    preview: ["#052e16", "#14532d", "#10b981"],
    accent: "emerald",
  },
  {
    id: "ocean",
    name: "Ocean",
    description: "Azul • profundidade oceânica",
    preview: ["#082f49", "#0c4a6e", "#0ea5e9"],
    accent: "sky",
  },
  {
    id: "sunset",
    name: "Sunset",
    description: "Pôr do sol • roxo e laranja",
    preview: ["#1a0a1f", "#581c87", "#f97316"],
    accent: "orange",
  },
];

let current = $state<ThemeId>("dark");

export function useTheme() {
  return {
    get current() { return current; },
    get theme() { return themes.find(t => t.id === current) ?? themes[0]; },
    get all() { return themes; },
    setTheme(id: ThemeId) {
      current = id;
      if (typeof window !== "undefined") {
        document.documentElement.setAttribute("data-theme", id);
        document.documentElement.classList.remove(...themes.map(t => `theme-${t.id}`));
        document.documentElement.classList.add(`theme-${id}`);
        localStorage.setItem("fm-theme", id);
      }
    },
    init() {
      if (typeof window !== "undefined") {
        const saved = localStorage.getItem("fm-theme") as ThemeId | null;
        const initial = saved && themes.some(t => t.id === saved) ? saved : "dark";
        this.setTheme(initial);
      }
    },
  };
}
