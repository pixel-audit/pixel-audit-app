import { createFileRoute, useNavigate } from "@tanstack/react-router";

import { okData } from "@/components/crud/api-response";
import { FunnelReport } from "@/components/funnels/funnel-report";
import { useApi } from "@/lib/api";
import { isIsoDate, rangeFromSearch, type DateRange } from "@/lib/date-range";
import { parseModes, serializeModes } from "@/lib/source-modes";

type ReportSearch = Partial<DateRange> & { show?: string };

/**
 * The View tab: the report. The range and how each data source is drawn
 * (`show=db:outline,warehouse:hidden`) are in the address, so a reload —
 * or a link sent on — shows the same picture.
 */
export const Route = createFileRoute("/funnels_/$id/")({
  validateSearch: (search: Record<string, unknown>): ReportSearch => ({
    date_from: isIsoDate(search.date_from) ? search.date_from : undefined,
    date_to: isIsoDate(search.date_to) ? search.date_to : undefined,
    show: serializeModes(parseModes(search.show)),
  }),
  component: FunnelViewTab,
});

function FunnelViewTab() {
  const { id } = Route.useParams();
  const search = Route.useSearch();
  const navigate = useNavigate({ from: Route.fullPath });
  const funnel = okData(useApi().useAdminGetFunnel(id).data)?.data;
  if (!funnel) return null;

  const range = rangeFromSearch(search);
  const modes = parseModes(search.show);

  return (
    <FunnelReport
      funnel={funnel}
      range={range}
      modes={modes}
      onRangeChange={(next) =>
        void navigate({
          search: (previous) => ({ ...previous, ...next }),
          replace: true,
          resetScroll: false,
        })
      }
      onModeChange={(sourceCode, mode) =>
        void navigate({
          search: (previous) => ({
            ...previous,
            show: serializeModes({ ...modes, [sourceCode]: mode }),
          }),
          replace: true,
          // The toggle sits in the table, below the chart: the page stays put.
          resetScroll: false,
        })
      }
    />
  );
}
