<script lang="ts">
  import "../app.css";
  import { onMount } from "svelte";
  import { useTheme } from "$lib/stores/theme.svelte";
  let { children } = $props();
  const theme = useTheme();
  onMount(() => theme.init());
</script>

{@render children()}
