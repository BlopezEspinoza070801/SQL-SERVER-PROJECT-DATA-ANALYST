--Queries VALIDACION DE DTOS

--1. Validar que no hay datos null
  
  SELECT *
  FROM SALES AS s
      LEFT JOIN Store AS st
      ON st.StoreKey=s.StoreKey
      left join Product AS p
      ON p.ProductKey=s.ProductKey
      left join Customer AS c
      ON c.CustomerKey=s.CustomerKey
      WHERE st.StoreKey is null 
            or p.ProductKey is null 
            or c.CustomerKey is null;
---Resultado=Todo OK


--2. Validar  que cada tienda usa solo un tipo de moneda o varios
SELECT StoreKey,
        COUNT(DISTINCT Currency) AS number_currency
FROM Sales
GROUP BY StoreKey
ORDER BY number_currency DESC;
---Resultado=Solo la tienda virtual acepta diferentes tipos de moneda y todas las tiendas físicas reciben solo un tipo de moneda.

--3 Validar si hay pedidos no entregados de tiendas virtuales o si en tiendas físicas se han hecho envios de delivery
--3.1 Tienda virtual
SELECT *
FROM Sales
WHERE Delivery_Date IS NULL AND StoreKey='0';
--Resultado=Todo OK
--3.2 Tienda fisica
SELECT *
FROM Sales
WHERE Delivery_Date IS NOT NULL AND StoreKey<>'0';
--Resultado=Todo OK

--4 Longitud de mis datos de tiempo
SELECT MIN(order_date) AS min_order,
       MAX(order_date) AS max_order
FROM sales;

--5 Creacion de vista usada recurrentemente
 -- Ignorar el año 2021 y añadir en la tabla de hechos el costo y precio */

CREATE VIEW sales_2 AS
SELECT s.*,
       p.Unit_Costo_USD,
       p.Unit_Price_USD
FROM sales as s
    left join Product as p
    ON p.ProductKey=s.ProductKey
    WHERE YEAR(s.Order_Date)<>2021;

--Queries EXPLORACION DE DATOS

--1. En terminos anuales,¿Como va las ventas y utilidad bruta de todo el grupo?
WITH ventas_costo AS(
SELECT DATETRUNC(YEAR,Order_Date) AS Año,
       SUM(quantity*Unit_Price_USD) AS Ventas,
       SUM(quantity*Unit_Costo_USD) AS Costo,
       SUM(quantity*(Unit_Price_USD-Unit_Costo_USD)) AS UtilidadB
FROM sales_2
GROUP BY DATETRUNC(YEAR,Order_Date)
)
SELECT Año,
       FORMAT(Ventas,'N2') AS Ventas,
       FORMAT((Ventas-LAG(Ventas,1) OVER(ORDER BY Año ASC))/LAG(Ventas,1) OVER(ORDER BY Año asc),'P2') AS LYvsY_Ventas,
       FORMAT(Costo,'N2') AS Costo,
       FORMAT((Costo-LAG(Costo,1) OVER(ORDER BY Año asc))/LAG(Costo,1) OVER(ORDER BY Año asc),'P2') AS LYvsY_Costo,
       FORMAT(UtilidadB,'N2') AS UtBruta,
       FORMAT(UtilidadB/Ventas,'P2') AS MargenBruto
FROM ventas_costo;


--2.¿Cuál es la tienda que vende más?

--Verificamos que todas las tiendas tengan metros cuadrados
SELECT *
FROM Store
WHERE StoreKey<>'0'
and (SquareMeters is null or SquareMeters=0);
--Resultado=Todas las tiendas tienen m2 menos la tienda virtual

SELECT st.State,
       st.Country,
       DATEDIFF(YEAR,st.OpenDate,GETDATE()) AS Years,
       DENSE_RANK() OVER(ORDER BY SUM(s.quantity*s.Unit_Price_USD) DESC) AS TOP_VENTAS,
       FORMAT(SUM(s.quantity*s.Unit_Price_USD),'N2') AS Ventas,
       FORMAT(SUM(s.quantity*(s.Unit_Price_USD-s.Unit_Costo_USD)),'N2') AS UtilidadB,
       ROUND(SUM(s.quantity*s.Unit_Price_USD)/MAX(st.squaremeters),3) AS Ventasxm2
FROM sales_2 AS s
    LEFT JOIN Store AS st
    ON s.StoreKey=st.StoreKey
    GROUP BY st.State,st.Country,st.OpenDate
    ORDER BY Ventasxm2 DESC;
    
SELECT st.State,
       st.Country,
       DATEDIFF(YEAR,st.OpenDate,GETDATE()) AS Years,
       MIN(s.Order_Date) as First_Sales,
       MAX(s.Order_Date) as Last_Sales,
       DENSE_RANK() OVER(ORDER BY SUM(s.quantity*s.Unit_Price_USD) DESC) AS TOP_VENTAS,
       FORMAT(SUM(s.quantity*s.Unit_Price_USD),'N2') AS Ventas,
       FORMAT(SUM(s.quantity*(s.Unit_Price_USD-s.Unit_Costo_USD)),'N2') AS UtilidadB,
       ROUND(SUM(s.quantity*s.Unit_Price_USD)/MAX(st.squaremeters),3) AS Ventasxm2
FROM sales_2 AS s
    LEFT JOIN Store AS st
    ON s.StoreKey=st.StoreKey
     WHERE st.Country='Australia'
    GROUP BY st.State,st.Country,st.OpenDate
    ORDER BY Ventasxm2 DESC;

----------------
--3. Tienda virtual vs todas las tiendas Fisicas

SELECT CASE WHEN StoreKey='0' THEN 'Virtual' ELSE 'Fisica' END AS Tipo_tienda,
       DATETRUNC(YEAR,order_date) AS year_date,
       SUM(quantity*Unit_Price_USD) AS Ventas,
       FORMAT(CAST(SUM(quantity*Unit_Price_USD) AS numeric)/SUM(SUM(quantity*Unit_Price_USD)) OVER(PARTITION BY DATETRUNC(YEAR,order_date) ),'P2') as porc_Ventas
FROM sales_2
GROUP BY CASE WHEN StoreKey='0' THEN 'Virtual' ELSE 'Fisica' END,
         DATETRUNC(YEAR,order_date)
ORDER BY Tipo_tienda DESC,year_date ASC

--4.¿Qué productos roto más y me generan mayor utilidad?
CREATE VIEW top_movimiento AS
WITH un_vendidas AS (
SELECT ProductKey,
        SUM(Quantity) AS Total
FROM Sales_2
GROUP BY ProductKey)
SELECT ProductKey,
        Total,
        SUM(Total) OVER () AS GLOBAL,
        SUM(total) OVER (ORDER BY Total DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Acumulado,
        CAST(SUM(total) OVER (ORDER BY Total DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS NUMERIC)/SUM(Total) OVER () AS Acumulado2
FROM un_vendidas;

SELECT ProductKey,
       Total,
       FORMAT(Acumulado2,'P2') AS porc_acum
FROM top_movimiento
WHERE Acumulado2<0.1;


CREATE VIEW top_utilidad AS
WITH utilidad_bruta AS(
SELECT ProductKey,
        SUM(Quantity*(Unit_Price_USD-Unit_Costo_USD)) AS Utilidad_B
FROM Sales_2
GROUP BY ProductKey)
SELECT ProductKey,
        Utilidad_B,
        SUM(Utilidad_B) OVER () AS GLOBAL,
        SUM(Utilidad_B) OVER (ORDER BY Utilidad_B DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Acumulado,
        CAST(SUM(Utilidad_B) OVER (ORDER BY Utilidad_B DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS NUMERIC)/SUM(Utilidad_B) OVER () AS Acumulado2
FROM utilidad_bruta;

SELECT ProductKey,
       Utilidad_B,
       FORMAT(Acumulado2,'P2') AS porc_acum
FROM top_utilidad
WHERE Acumulado2<0.1;

--Cruce entre ambos grupos
SELECT * FROM
Product
WHERE ProductKey in 
(
SELECT ProductKey
FROM top_movimiento
WHERE Acumulado2<0.1

INTERSECT

SELECT ProductKey
FROM top_utilidad
WHERE Acumulado2<0.1);

-- 5 ¿Cómo se comporta el leadtime de los pedidos del canal virtual?
--Juntamos los pedidos a 1 solo x fila
WITH pedidos_unicos AS(
SELECT distinct order_number,order_date,delivery_date
FROM Sales_2
WHERE StoreKey='0')

SELECT COALESCE(CAST(YEAR(order_date) AS VARCHAR),'Total') AS year_order,
        MAX(datediff(day,Order_Date,Delivery_Date)) AS max_leadtime,
        avg(datediff(day,Order_Date,Delivery_Date)) AS avg_leadtime,
        Min(datediff(day,Order_Date,Delivery_Date)) AS min_leadtime
FROM pedidos_unicos
GROUP BY CUBE(year(order_date));

--6. LeadTime Categorizado
WITH pedidos_unicos AS(
SELECT distinct order_number,order_date,delivery_date
FROM Sales_2
WHERE StoreKey='0'),
tipo_entrega AS(
SELECT 
    DATETRUNC(YEAR,order_date) AS year_order,
    CASE WHEN DATEDIFF(day,order_date,delivery_date)<4 THEN  'A'
         WHEN DATEDIFF(day,order_date,delivery_date)<10 THEN  'B'
         ELSE 'C' end as Tipo_Entrega,
    COUNT(*) AS N_pedidos
FROM pedidos_unicos
GROUP BY DATETRUNC(YEAR,order_date),
            CASE WHEN datediff(day,order_date,delivery_date)<4 then  'A'
                 WHEN datediff(day,order_date,delivery_date)<10 then  'B'
                 ELSE 'C' end)
SELECT year_order,
       Tipo_Entrega,
       N_pedidos,
       format(cast(N_pedidos-LAG(N_pedidos,1) OVER( PARTITION BY tipo_entrega ORDER BY year_order) AS numeric)/LAG(N_pedidos,1) OVER(PARTITION BY tipo_entrega ORDER BY year_order),'P2') AS lyvsy,
       format(cast(N_pedidos as numeric)/sum(N_pedidos) OVER(PARTITION BY year_order),'P2') AS porc_ge
FROM tipo_entrega
ORDER BY Tipo_Entrega ASC,year_order ASC;

--7 ¿Pedidos al año por cliente?
WITH pedidos_globales AS (
SELECT DISTINCT order_date,CustomerKey,Order_Number
FROM sales_2)
SELECT DATETRUNC(YEAR,Order_Date) as year_order,
        COUNT(*) AS Total_Pedidos,
        COUNT(DISTINCT CustomerKey) as Clientes,
        FORMAT(CAST(COUNT(*) as numeric)/ COUNT(DISTINCT CustomerKey),'N2') as FrecuenciaCompras
from pedidos_globales
GROUP BY DATETRUNC(YEAR,Order_Date)
ORDER BY year_order ASC;

---8. ¿Cuantos clientes realizan más de una compra anual?
WITH clasificacion_cliente AS(
SELECT CustomerKey,
       DATETRUNC(YEAR,Order_Date) AS year_date,
       COUNT( DISTINCT Order_Number) AS Total_Pedidos,
       CASE WHEN COUNT( DISTINCT Order_Number)<=2 then '1-2'
            when COUNT( DISTINCT Order_Number)<=5 then '3-5'  
            else '6-más' END AS clasificacion
FROM Sales_2
GROUP BY CustomerKey,DATETRUNC(year,Order_Date))
SELECT year_date,
       clasificacion,
       COUNT(customerkey) AS Numero_Clientes,
       SUM(TOTAL_PEDIDOS) AS Pedidos,
       FORMAT(CAST(COUNT(customerkey) AS numeric)/ SUM(COUNT(customerkey)) OVER(PARTITION BY year_date),'P2') as porc_anual
FROM clasificacion_cliente
GROUP BY year_date,clasificacion
ORDER BY clasificacion ASC,year_date ASC;

---9. ¿Como evaluo las ventas bajo la moneda de pago o bajo una moneda estándar?
--Vamos haber que tanto cambian los números si se evalua con la moneda local o la moneda USD Dolar

WITH DOLAR_OTHERS AS(
SELECT s.StoreKey,
       DATETRUNC(YEAR,s.Order_Date) AS  year_order,
      s.Currency,  
      SUM(s.Quantity*s.Unit_Price_USD) AS ventas_dolares,
      SUM(s.Quantity*s.Unit_Price_USD*er.Exchange)AS ventas_moneda
FROM sales_2 AS s
    LEFT JOIN Exchange_Rates AS er
    ON s.Currency=er.Currency AND s.Order_Date=er.Date
WHERE s.Currency<>'USD' AND s.StoreKey<>'0'
GROUP BY s.StoreKey,
     DATETRUNC(YEAR,s.Order_Date), 
     s.Currency ),
dolar_others2 as(
SELECT 
        StoreKey,
        year_order,
        Currency,
        ventas_dolares,
         (ventas_dolares-LAG(ventas_dolares,1) OVER(PARTITION BY StoreKey ORDER BY year_order ASC))/LAG(ventas_dolares,1) OVER(PARTITION BY StoreKey ORDER BY year_order ASC) as ly_vs_y_dolar,
        ventas_moneda,
         (ventas_moneda-LAG(ventas_moneda,1) OVER(PARTITION BY Storekey ORDER BY year_order ASC))/LAG(ventas_moneda,1) OVER(PARTITION BY StoreKey ORDER BY year_order ASC) as ly_vs_y_otros
FROM DOLAR_OTHERS)
SELECT StoreKey,
       YEAR_ORDER,
       currency,
       FORMAT(ly_vs_y_dolar,'P2') AS var_dolar,
       FORMAT(ly_vs_y_otros,'P2') AS var_local,
       FORMAT(ly_vs_y_dolar-ly_vs_y_otros,'P2') as variacion_moneda
FROM dolar_others2
WHERE ABS(ly_vs_y_dolar-ly_vs_y_otros)>0.1

--10.1 Impacto del tipo de canal en las ventas generales
---Hay clientes que han hecho compras online y en tienda presencial
SELECT CustomerKey,
       COUNT(DISTINCT CASE WHEN StoreKey='0' then 1 else 2 end ) numero_tiendas
FROM sales_2
GROUP BY CustomerKey
ORDER BY numero_tiendas DESC
/* Debido a que nuestra fecha de venta solo llega a nivel de dia y no horas ,puede que haya clientes que su primera fecha de compra
tiene ventas en tiendas fisicas y virtuales,se usara la casuastica de que en esos casos para desempate se dara prioridad a la virtual
*/
SELECT s.Customerkey,
       COUNT(DISTINCT CASE WHEN s.storekey='0' THEN 'Virtual' ELSE 'Fisico' END) AS numero_tiendas_primera_compra
FROM sales_2 as s
INNER JOIN(
SELECT CustomerKey,
        min(order_date) as min_fecha
FROM sales_2
GROUP BY CustomerKey) AS mini
ON mini.CustomerKey=s.CustomerKey
   AND mini.min_fecha=Order_Date
GROUP BY s.CustomerKey
ORDER BY numero_tiendas_primera_compra DESC
/* Solo sale un cliente con ese caso especial,la solucion más facil seria evaluar sus ventas si son representativas y eliminarla,
    pero mejor trabajamos bajo la premisa de que pueden repetirse más casos como estos en el futuro y se dará prioridad primero al canal virtual,no
    se puede usar el numero de orden de pedido porque no sabemos que logica tiene para ser armado la digitacion de este
*/

WITH order_compras as(
    SELECT CustomerKey,
           order_date,
           CASE WHEN storekey='0' then 'Virtual' else 'Fisico' end as Canal_entrada,
    ROW_NUMBER() OVER(PARTITION BY CustomerKey ORDER BY order_date ASC,CASE WHEN storekey='0' THEN 0 ELSE 1 END ASC) AS ranking
FROM sales_2),
primera_operacion as (
SELECT * FROM 
order_compras
WHERE ranking=1),
versus_canal as(
SELECT DATETRUNC(YEAR,s.Order_Date) as year_order,
       po.Canal_entrada,
       CASE WHEN s.storekey='0' then 'Virtual' else 'Fisico' end AS Canal_Venta,
       SUM(s.quantity*s.unit_price_usd) as Ventas,
       COUNT( DISTINCT s.Order_Number) as Num_pedidos
FROM sales_2 as s
LEFT JOIN primera_operacion as po
ON po.CustomerKey=s.CustomerKey
GROUP BY DATETRUNC(YEAR,s.Order_Date),
       po.Canal_entrada,
       CASE WHEN s.storekey='0' then 'Virtual' else 'Fisico' end)
SELECT year_order,
       Canal_entrada,
       Canal_Venta,
       Num_pedidos,
       FORMAT(Ventas,'N2') AS Ventas,
       FORMAT(Ventas/SUM(Ventas) OVER(PARTITION BY year_order,Canal_entrada),'P2') AS porc_anual
FROM versus_canal
ORDER BY Canal_entrada,year_order,Canal_Venta;

--10.2 Impacto del tipo de canal en las ventas generales a detalle
/*Se quiere medir el impacto anual de los clientes nuevos en ese año,claro que hay clientes que ingresaron al inicio,mediados
o fin de año y que tuvieron poco tiempo para probar el otro canal,pero ese ya seria un análisis más profundo que por el momento no se tocará
ya que la idea es ver el impacto entre canales y como son afectados
*/

WITH order_compras AS(
    SELECT CustomerKey,
           order_date,
           CASE WHEN storekey='0' THEN 'Virtual' ELSE 'Fisico' END AS Canal_entrada,
    ROW_NUMBER() OVER(PARTITION BY CustomerKey ORDER BY order_date asc,CASE WHEN storekey='0' THEN 0 ELSE 1 END ASC) AS ranking
FROM sales_2),
primera_operacion AS (
SELECT * FROM 
order_compras
WHERE ranking=1),
versus_canal AS(
SELECT DATETRUNC(YEAR,s.Order_Date) AS year_order,
       po.Canal_entrada,
       CASE WHEN s.storekey='0' THEN 'Virtual' ELSE 'Fisico' END AS Canal_Venta,
       SUM(s.quantity*s.unit_price_usd) AS Ventas,
       COUNT( DISTINCT s.Order_Number) AS Num_pedidos
FROM sales_2 as s
LEFT JOIN primera_operacion as po
ON po.CustomerKey=s.CustomerKey
Where DATETRUNC(YEAR,po.Order_Date)=DATETRUNC(year,s.order_date)
GROUP BY DATETRUNC(YEAR,s.Order_Date),
       po.Canal_entrada,
       CASE WHEN s.storekey='0' then 'Virtual' else 'Fisico' end)
SELECT year_order,
       Canal_entrada,
       Canal_Venta,
       Num_pedidos,
       FORMAT(Ventas,'N2') AS Ventas,
       FORMAT(Ventas/SUM(Ventas) OVER(PARTITION BY year_order,Canal_entrada),'P2') AS porc_anual
FROM versus_canal
ORDER BY Canal_entrada,year_order,Canal_Venta;