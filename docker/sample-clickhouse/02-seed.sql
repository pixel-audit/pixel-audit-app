-- Sixty days of events; the step counts shrink down the funnel.
INSERT INTO shop.events
SELECT name, rand() % 100000, now() - toIntervalDay(d) - toIntervalSecond(rand() % 86400)
FROM (SELECT number AS d FROM numbers(60)) days
ARRAY JOIN
  ['page_view', 'view_content', 'add_to_cart', 'purchase'] AS name,
  [1000, 600, 150, 40] AS base
ARRAY JOIN range(base + rand() % 50) AS i
