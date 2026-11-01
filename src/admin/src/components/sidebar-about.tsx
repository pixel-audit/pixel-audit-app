import { defineMessages, useIntl } from "react-intl";

import { config } from "@/lib/config";
import { RELEASE } from "@/lib/release";

/**
 * One sentence beside the sidebar's fold toggle, in a box of fixed height
 * so the toggle never moves: "PixelAudit — free software under the GNU
 * AGPL v3.", where the name links to the source and, in a built release,
 * the build follows the name: the tag it was made from (v0.0.4), linked to
 * the release, or else the short commit, linked to it. The box clips
 * rather than grows, so the text may wrap to its second line while the
 * sidebar animates and nothing else shifts.
 *
 * PixelAudit is AGPL-3.0 software, and §13 of the licence asks a program
 * used over a network to offer its source to those who use it — the link
 * is that offer, pointed at the deployment's own repository through
 * `sourceUrl` (public/config.js). The commit and tag are CI's
 * (`VITE_RELEASE_SHA`, `VITE_RELEASE_TAG`, the image's build arguments); a
 * local dev build carries neither.
 */
export function SidebarAbout() {
  const intl = useIntl();
  const linkClass = "underline-offset-2 hover:text-sidebar-foreground hover:underline";
  return (
    <p className="h-[22px] min-w-0 overflow-hidden text-[10px] leading-[11px] text-sidebar-foreground/60">
      <a href={config.sourceUrl} target="_blank" rel="noreferrer" className={linkClass}>
        {intl.formatMessage(messages.name)}
      </a>
      {RELEASE.tag !== null ? (
        <>
          {" "}
          <a
            href={`${config.sourceUrl}/releases/tag/${RELEASE.tag}`}
            target="_blank"
            rel="noreferrer"
            className={`font-mono ${linkClass}`}
            title={RELEASE.sha ?? undefined}
          >
            {RELEASE.tag}
          </a>
        </>
      ) : (
        RELEASE.sha !== null && (
          <>
            {" "}
            <a
              href={`${config.sourceUrl}/commit/${RELEASE.sha}`}
              target="_blank"
              rel="noreferrer"
              className={`font-mono ${linkClass}`}
              title={RELEASE.sha}
            >
              {RELEASE.sha.slice(0, 7)}
            </a>
          </>
        )
      )}{" "}
      {intl.formatMessage(messages.licence)}
    </p>
  );
}

const messages = defineMessages({
  name: { id: "about.name", defaultMessage: "PixelAudit" },
  licence: { id: "about.licence", defaultMessage: "— free software under the GNU AGPL v3." },
});
