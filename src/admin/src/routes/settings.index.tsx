import { createFileRoute, redirect } from "@tanstack/react-router";

import { firstScreen, groupOf } from "@/lib/navigation";

// The group has no page of its own: /settings leads to its first screen.
export const Route = createFileRoute("/settings/")({
  beforeLoad: () => {
    const group = groupOf("/settings");
    throw redirect({ to: group ? firstScreen(group) : "/" });
  },
});
