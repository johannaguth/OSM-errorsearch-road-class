CREATE OR REPLACE FUNCTION calc_alpha(
  x double precision,
  y double precision
) RETURNS double precision
AS $$
import math

if x > 0 and y >= 0:
    alpha = math.asin(y/(math.sqrt(y**2 + x**2)))
elif x <= 0 and y > 0:
    alpha = math.pi/2 + (math.pi/2 - math.asin(y/(math.sqrt(y**2 + x**2))))
elif x < 0 and y <= 0:
    alpha = math.pi - math.asin(y/(math.sqrt(y**2 + x**2)))
elif x >= 0 and y < 0:
    alpha = math.pi*2 + (math.asin(y/(math.sqrt(y**2 + x**2))))
else:
    plpy.info("X = " + str(x) + "    Y = " + str(y))


return alpha
$$ LANGUAGE plpython3u;
