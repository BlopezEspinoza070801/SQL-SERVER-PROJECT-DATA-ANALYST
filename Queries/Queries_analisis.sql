--Queries VALIDACION DE DTOS

--1. Validar que no hay datos null
  --Debido a que las tablas cuando se cargaron se definieron primary key estas no pueden ser null,pero validaremos que las llaves secundarias no tengan valores null
  SELECT *
  FROM SALES AS s
      LEFT JOIN Store AS st
      ON st.StoreKey=s.StoreKey
      left join Product AS p
      ON p.ProductKey=s.ProductKey
      left join Customer AS c
      ON c.CustomerKey=s.CustomerKey
      WHERE s.StoreKey is null 
            or s.ProductKey is null 
            or s.CustomerKey is null;
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
/* Como solo se tiene hasta febrero 2021 se ignorara todo el 2021 para analizar años completos,pero como tampoco 
queremos perder esos datos, se creara una vista de tal manera que se conserve la info del 2021 */

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
/*
Las ventas y costos han ido creciendo año a año a un ritmo casi simillar,y el Margen Bruto se ha mantenido entre el 58 y 59%,
pero se ve un bajon marcado en el 2020 de practicamente de un 50% comparado a los resultados del 2019,habria que evaluar cual fue la causa
de ese desplome,una de las hipótesis que se pueden manejar es el impacto de la Pandemia del COVID-19 pero en el dataset no tenemos datos
para validar esto. */


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
    
/* 
Un buen indicador seria ver solo las ventas brutas,pero tomando en cuenta que cada tienda tienen factores ambientales diferentes,
ya que no es lo mismo vender en una tienda de 200 m2 con 10 trabajadores que en una tienda de 30 m2 con 3 trabajadores,por lo
que una medida más justa seria usar las Ventas/m2.
Y observamos que la tienda Online es la que ha tenido las mayores ventas superando a tiendas que tienen mucho más años de antigüedad,esto es un
buen indicador a alto nivel de que el sector e-commerce es clave,pero lo que mas resalta es que la tienda Northen Territory Australia esta
por debajo de los $20/m2,por lo que antes de sacar alguna conclusion sobre su viabilidad validaremos el estado de todo el grupo de tiendas de ese país
*/
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

/*Se observa que todas las tiendas an Australia han tenido operaciones hasta el 2020,pero lo extraño es que la tienda
Northern Territory solo ha tenido ventas hasta Abril del 2016 por lo que eso justificaria porque sus ventas/m2 son tan bajas,
por lo que habría que preguntar si ese punto de venta sigue realmente activo o es una tienda que cerro operaciones

Pero en general la conclusion que si podemos llegar es que las ventas online son clave,ya que venden más que cualquier tienda fisica por lo que es
una primera señal para manejar la idea de impulsar con más recursos toda esa área
*/
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

/*
Se observa que en el 2016 las ventas virtuales comenzaron representando solo el 16% de las ventas anuales pero cerro el 2020 representando el 22.3% de las ventas totales,
ese aumento de practicamente 6 puntos porcentuales nos indica o da indicio a una tendencia al aumento constante de ventas por el canal virtual,lo que vuelve a reforzar la idea
de impulsar más ese canal.
*/


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
/*
De los 2592 skus que en algun momento se han vendido,solo 42 engloban el 10% de las ventas glovales
por lo que estos son los productos clave a nivel de rotación que no deberian faltar en todas las tiendas por lo que
se deberia revisar si existen inventarios de seguridad de acuerdo para evitar quiebres
Un análisis más profundo sería validar por cada pais que productos son los de mayor rotación y enfocarse en su disponibilidad en las tiendas de cada pais.
*/

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


/*
De los 2592 skus que se han vendido solo 11 skus engloban el 10% de la Utilidad Bruta de forma histórica,por lo que si realizamos un cruce con los de alta rotacion
Encontaremos los productos clave tanto en movimiento como en rotaçión
*/
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

/*
Eso nos arrojaria los skus estrella que hay que cuidar tanto en rotacion y que generan una mayor ganancia a la empresa,podemos ver que nos sale 7 skus clave pero en si son solo
2 productos solo que en diferente presentacion de colores,por lo que en un análisis más profundo se podria ver cuanto influye el color en la venta de un mismo producto.
Igualmente se recomienda realizar el análisis a nivel de cada pais para poder observar el comportamiento real de cada grupo de tiendas por país.
*/


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
/*
--Se ve que el promedio de dias de entrega ha pasado de 7 dias en el 2016 a 4 dias desde el 2018 en adelante,lo cual es una reducción considerable
y es una buena señal de que el servicio de envio ha ido mejorando a través de los años,pero también se ve que hay casos donde el tiempo ha sido hasta de 17 o 13 dias
por lo que para validar la mejora del envio año tras año se realizará un análisis más profundo
*/


--6. LeadTime Categorizado
WITH pedidos_unicos AS(
SELECT distinct order_number,order_date,delivery_date
FROM Sales_2
WHERE StoreKey='0'),
tipo_entrega as(
SELECT 
    DATETRUNC(YEAR,order_date) as year_order,
    CASE WHEN datediff(day,order_date,delivery_date)<4 then  'A'
         WHEN datediff(day,order_date,delivery_date)<10 then  'B'
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
       format(cast(N_pedidos-LAG(N_pedidos,1) over( partition by tipo_entrega order by year_order) AS numeric)/LAG(N_pedidos,1) over( partition by tipo_entrega order by year_order),'P2') AS lyvsy,
       format(cast(N_pedidos as numeric)/sum(N_pedidos) over(partition by year_order),'P2') AS porc_ge
FROM tipo_entrega
order by Tipo_Entrega ASC,year_order asc

/*
Se observa que los pedidos de Tipo C que demoraban de 10 a más han ido disminuyendo año tras año,tanto si lo vemos como una comparación con el año pasado como una comparación
de los pedidos globales de ese año por lo que se valida que se esta mejorando el tiempo de envios año tras año,un análisis mas profundo sería ver la causa de esas demoras
tal vez se terceriza el transporte o el despacho demora mucho,pero el dataset no da información para poder comprobar dichas premisas
*/

--7 ¿Pedidos al año por cliente?
WITH pedidos_globales AS (
SELECT DISTINCT order_date,CustomerKey,Order_Number
FROM sales_2)
SELECT DATETRUNC(year,Order_Date) as year_order,
        count(*) AS Total_Pedidos,
        count(distinct CustomerKey) as Clientes,
        format(cast(count(*) as numeric)/ count(distinct CustomerKey),'N2') as FrecuenciaCompras
from pedidos_globales
GROUP BY DATETRUNC(year,Order_Date)
ORDER BY year_order ASC

/*
Se puede ver que apesar de los pedidos han ido aumentando año a año la frecuencia de compras nunca psada de 1.5;por lo que es una señal de
que a nivel global la mayoria de clientes no repiten compras en el mismo año,esto podria ser un sintoma de que el negocio no tiene una cultura de retención de clientes
o por la naturaleza de sus productos es complicado generar una retención,igualmente esta en una vista general por lo que hay que hacer un análisis más profundo
*/

---8. ¿Cuantos clientes realizan más de una compra anual?
WITH clasificacion_cliente AS(
SELECT CustomerKey,
       DATETRUNC(year,Order_Date) as year_date,
       COUNT( distinct Order_Number) as Total_Pedidos,
       case when COUNT( distinct Order_Number)<=2 then '1-2'
            when COUNT( distinct Order_Number)<=5 then '3-5'  
            else '6-más' END AS clasificacion
FROM Sales_2
GROUP BY CustomerKey,DATETRUNC(year,Order_Date))
SELECT year_date,
       clasificacion,
       count(customerkey) as Numero_Clientes,
       SUM(TOTAL_PEDIDOS) as Pedidos,
       format(cast(count(customerkey) as numeric)/ sum(count(customerkey)) over(partition by year_date),'P2') as porc_anual
FROM clasificacion_cliente
GROUP BY year_date,clasificacion
ORDER BY clasificacion asc,year_date asc
/*
Se habia visto que de forma global el número de pedidos por cliente no pasaban los 1.5 pedidos pero ahora a la clasterización se le añade una clasificación
podemos ver que los clientes que han hecho entre 3-5 pedidos anuales han ido aumentando cada año pasando de ser solo 19 clientes en el 2016 a ser 478 en el 2019 y 92 
en el 2020,ya vimos que 2020 tuvo una caida atípica ,de forma porcental se puede ver que iniciamos con que un 1% de los clientes hacian entre 3 a 5 compras en el 2016
y en el 2019 el 7.3% de clientes hicieron entre 3-5 compras,sin contar el caso especial de 2020 que hubo un bajo,y otra cosa en el 2019 fue el 1er año donde aparecio
el grupo de clientes que hace más de 6 pedidos,solo fueron 4 clientes pero es un inicio de que la retención esta aumentando a un ritmo bajo que hace que si se mira de 
forma global no se perciba mucho,pero si hay.
*/
 
---9. ¿Como evaluo las ventas bajo la moneda de pago o bajo una moneda estándar?
--Vamos haber que tanto cambian los números si se evalua con la moneda local o la moneda USD Dolar

WITH DOLAR_OTHERS AS(
SELECT S.STOREKEY,
       DATETRUNC(YEAR,S.Order_Date) AS YEAR_ORDER,
      S.CURRENCY,  
      SUM(S.QUANTITY*S.UNIT_PRICE_USD) AS ventas_dolares,
      SUM(S.QUANTITY*S.UNIT_PRICE_USD*ER.Exchange)AS ventas_moneda
FROM SALES_2 AS S
    LEFT JOIN Exchange_Rates AS ER
    ON S.Currency=ER.Currency AND S.Order_Date=ER.Date
WHERE S.Currency<>'USD' AND StoreKey<>'0'
GROUP BY S.STOREKEY,
     DATETRUNC(YEAR,S.Order_Date), 
     S.CURRENCY ),
dolar_others2 as(
SELECT 
        StoreKey,
        YEAR_ORDER,
        Currency,
        ventas_dolares,
         (ventas_dolares-LAG(ventas_dolares,1) OVER(PARTITION BY STOREKEY ORDER BY YEAR_ORDER ASC))/LAG(ventas_dolares,1) OVER(PARTITION BY STOREKEY ORDER BY YEAR_ORDER ASC) as ly_vs_y_dolar,
        ventas_moneda,
         (ventas_moneda-LAG(ventas_moneda,1) OVER(PARTITION BY STOREKEY ORDER BY YEAR_ORDER ASC))/LAG(ventas_moneda,1) OVER(PARTITION BY STOREKEY ORDER BY YEAR_ORDER ASC) as ly_vs_y_otros
FROM DOLAR_OTHERS)
SELECT StoreKey,
       YEAR_ORDER,
       currency,
       FORMAT(ly_vs_y_dolar,'P2') AS var_dolar,
       FORMAT(ly_vs_y_otros,'P2') AS var_local,
       FORMAT(ly_vs_y_dolar-ly_vs_y_otros,'P2') as variacion_moneda
FROM dolar_others2
WHERE ABS(ly_vs_y_dolar-ly_vs_y_otros)>0.1

/*
Hay 12 registros donde si se evalua usando su moneda original las ventas aun aumentado de un 10% a 15% más si se compara con la moneda USD Dollar
que es la moneda en la que esta originalmente mis costos y precios de productos
por lo que no seria buena idea evaluar cada tienda segun su moneda propia ya que ese aumento artificial de ventas se podría deber principalmente
al tipo de cambio fluctuante por lo que lo mejor es evaluarlo todo en una sola moneda la cual seria el USD Dollar para cuando se quiere evaluar
temas de mejoras de rendimiento de vendedores o aumento de ventas generales
*/

--10 ¿Él tipo de cambio afecta cuando evaluo el TOP de ventas?
WITH DOLAR_OTHERS AS(
SELECT S.STOREKEY,
       DATETRUNC(YEAR,S.Order_Date) AS YEAR_ORDER,
      S.CURRENCY,  
      SUM(S.QUANTITY*S.UNIT_PRICE_USD) AS ventas_dolares,
      SUM(S.QUANTITY*S.UNIT_PRICE_USD*ER.Exchange)AS ventas_moneda
FROM SALES_2 AS S
    LEFT JOIN Exchange_Rates AS ER
    ON S.Currency=ER.Currency AND S.Order_Date=ER.Date
WHERE S.Currency<>'USD' AND StoreKey<>'0'
GROUP BY S.STOREKEY,
     DATETRUNC(YEAR,S.Order_Date), S.CURRENCY ),
dolar_final as(
select * ,
        DENSE_RANK() over(partition by year_order,currency order by ventas_dolares desc) as top_dolar,
        DENSE_RANK() over(partition by year_order,currency order by ventas_moneda desc) as top_otros
from dolar_others)
select *
from dolar_final
where top_dolar<>top_otros
order by YEAR_ORDER asc,currency,top_dolar asc

/*
Se ve que  si hay cambios sutiles en el top de ventas si es que se usa la moneda Dolar o su moneda local,pero se ve que los cambios son mínimos
entre dolar y otras monedas,por lo que se podria usar su moneda local como top para evaluar en grupo las tiendas que manejan una misma moneda para facilitar los calculos.
*/

--11 Impacto del tipo de canal en las ventas generales


---Hay clientes que han hecho compras online y en tienda presencial
SELECT CustomerKey,
       COUNT(DISTINCT CASE WHEN StoreKey='0' then 1 else 2 end ) numero_tiendas
FROM sales_2
GROUP BY CustomerKey
ORDER BY numero_tiendas desc
/* Debido a que nuestra fecha de venta solo llega a nivel de dia y no horas hay clientes que su primera fecha de compra
tiene ventas en tiendas fisicas y virtuales,se usara la casuastica de que en esos casos para desempate se dara prioridad a la virtual
*/
SELECT s.Customerkey,
       count(distinct case when s.storekey='0' then 'Virtual' else 'Fisico' end) as numero_tiendas_primera_compra
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
    pero mejor trabajamos bajo la premisa de que pueden repetirse más casos como estos en el futuro y se dará prioridad primero al canal virtual
*/

WITH order_compras as(
    SELECT CustomerKey,
           order_date,
           CASE WHEN storekey='0' then 'Virtual' else 'Fisico' end as Canal_entrada,
    ROW_NUMBER() OVER(PARTITION BY CustomerKey ORDER BY order_date asc,case when storekey='0' then 0 else 1 end ASC) as ranking
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
ORDER BY year_order,Canal_entrada,Canal_Venta;

/*
Canal de entrada fisico
Si se ve el año 2016,todos los pedidos realizados por los clientes que ingresaron por el canal físico,apenas el 1.48% de pedidos fueron para el canal virtual,y para
el 2019 y 2020 ese porcentaje paso al 14% y 18%,pero antes de sacar alguna conclusion hay que entender que los valores del 2019 y 2020 son altos porque estos valores
engloban los clientes que ingresaron al canal fisico desde el 2016,por lo que dichos clientes,por lo que una correcta interpretación sería decir
Para el 2019 y 2020,todos los clientes que han ingresado desde el 2016 hasta la fecha,de todas sus compras realizadas anualmente,el 14% y 17% fueron al canal virtual

Por lo que se puede ver que los clientes que ingresan por el canal fisico,un % de sus ventas pasan al canal virtual pero a pesar del efecto acumulado el porcentaje
maximo llega al 17%
*/
/*
Canal de entrada virtual
Si se ve en el año 2016,todos los pedidos realizados por clientes que ingresaron por canal virtual,el 6% de sus pedidos pasaron al canal físico y para el 2019 aumenta 
a casi 50%(su pico) y en el 2020 represento el 39% ,ambos números son mucho mayores al 6%,pero hay que tener encuenta el efecto acumulado otra vez,por lo que la conclusión
que se podria dar es que hay un  indicio de que el canal virtual apoya a que las ventas en el canal físico aumenten.
Pero para poder reforzar esa idea habria que revisarlo más a detalle
*/


--12 Impacto del tipo de canal en las ventas generales a detalle
/*Se quiere medir el impacto anual de los clientes nuevos en ese año,claro que hay clientes que ingresaron al inicio,mediados
o fin de año y que tuvieron poco tiempo para probar el otro canal,pero ese ya seria un análisis más profundo que por el momento no se tocará
ya que la idea es ver el impacto entre canales y como son afectados
*/

WITH order_compras as(
    SELECT CustomerKey,
           order_date,
           CASE WHEN storekey='0' then 'Virtual' else 'Fisico' end as Canal_entrada,
    ROW_NUMBER() OVER(PARTITION BY CustomerKey ORDER BY order_date asc,case when storekey='0' then 0 else 1 end ASC) as ranking
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
Where datetrunc(YEAR,po.Order_Date)=datetrunc(year,s.order_date)
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
ORDER BY year_order,Canal_Entrada,Canal_Venta;
/*
Ahora se puede el impacto anual de clientes que ingresan anualmente por el canal virtual
y se ve que el impacto explicado anteriormente de más del 30% es por un factor acumulado de antiguedad del cliente,
pero si se ve que en el 2018 y 2019 paso de un 6% inicial del 2016 a valores de 13.8% y 17.6% lo cual si es un aumento considerable
de que los clientes nuevos estan empezando a conocer el canal fisico gracias al canal virtual,en el 2020 el % bajo al 7% pero
hay que tener encuenta que fue un año atípico

Por lo que si se ve un impacto en el canal fisico gracias al canal virtual pero no es tan grande,el impacto grande
viene gracias al efecto acumulado de clientes antiguos,pero no deja de ser una idea interesante,ya que mientras mas clientes
ingresan por el canal virtual de manera historica sus ventas tienden a aumentar en el canal fisico.
Por  lo que refuerza la idea de impulsar el canal virtual no solo afecta sus ventas sino tambien las del canal fisico de forma acumulada.

*/