![DATA PROJECT](./Picture/banner.png)
# Project SQL:Análisis Global(Ventas-Clientes)

## Resumen (Overview)
La gerencia del area de ventas de *Mtech*,grupo empresarial de ventas de productos tecnológicos, desea un vistazo general de como se encuentra actualmente las ventas para poder identificar posibles fortalezas y debilidades para tomarlas en cuenta en el plan de trabajo del próximo año.

El objetivo de este proyecto es utilizar **SQL** dentro de **SQL Server Management Studio**,para poder analizar los datos y brindar recomendaciones al departamento de ventas que facilite la toma de decisiones.

## Estructura del Proyecto

- [Sobre los Datos](#sobre-los-datos)
- [Ingesta de Datos](#ingesta-de-datos)
- [Diagrama E-R](#diagrama-e-r)
- [Tareas](#tareas-task)
- [Limpieza de Datos](#limpieza-de-datos)
- [Análisis Exploratorio de Datos e Insights](#análisis-exploratorio-de-datos-eda-e-insights)



## Sobre los Datos

Los datos originales, junto con una explicación de cada columna, se pueden encontrar [aquí](https://www.kaggle.com/datasets/bhavikjikadara/global-electronics-retailers/data).

El conjunto de datos incluye cinco tablas con información al respecto de los **clientes,productos,Tiendas,Ventas,Tipo de cambio** de una empresa de ventas de productos electrónicos y que tiene varios puntos de venta físicos en diferentes paises y también un punto de venta virtual.


## Ingesta de Datos

Antes de realizar el análisis,se crea la base de datos y las conexiones necesarias entre la tabla hecho y las tablas dimension,pero se realiza un proceso de limpieza para poder trabajar correctamente

```sql
-- Limpieza y estandarizacion de tabla Sales

UPDATE Product
SET Unit_Costo_USD=TRIM(REPLACE(REPLACE(Unit_Costo_USD,'$',''),',','')),
    Unit_Price_USD=TRIM(REPLACE(REPLACE(Unit_Price_USD,'$',''),',',''))

--Validamos que no haya ningun valor perdido
SELECT Unit_Costo_USD, Unit_Price_USD
FROM Product
WHERE TRY_CONVERT(DECIMAL(10,3),Unit_Costo_USD) IS NULL
   OR TRY_CONVERT(DECIMAL(10,3),Unit_Price_USD) IS NULL;


ALTER TABLE Product
ALTER COLUMN Unit_Costo_USD DECIMAL(10,3);

ALTER TABLE Product
ALTER COLUMN Unit_Price_USD DECIMAL(10,3);

--Insertar llave primaria en Sales,Como buena practica

--Validamos que es unica la combinacion order_number,line y que no tenga valores null--
SELECT ORDER_NUMBER,LINE,
       COUNT(*)
FROM Sales
GROUP BY Order_Number,LINE
HAVING COUNT(*)>1;

SELECT ORDER_NUMBER,LINE
FROM Sales
where Order_Number is null or line is null;
--Hacemos que a futuro tampoco acepten valores null
ALTER TABLE SALES
ALTER COLUMN Order_Number NVARCHAR(100) NOT NULL;
ALTER TABLE SALES
ALTER COLUMN Line NVARCHAR(20) NOT NULL;
--Se crea la Primary Key
ALTER TABLE Sales
ADD CONSTRAINT PK_Sales PRIMARY KEY (Order_Number, Line)
```
## Diagrama-E-R

Se unieron las tablas dimensiones con la tabla hecho a través de sus llaves primarias y secundarias,no se realizo la conexión entre Exchange_Rates ya que no sera utilizada en la mayoria del projecto.
![DATA PROJECT](./Picture/DiagramaE-R.png)
## Tareas (Task)

En este análisis, la meta es ayudar al departamento de Ventas a responder las siguientes Preguntas:

1. **Ventas Generales**: En terminos anuales,¿Como va las ventas y utilidad bruta de todo el grupo?
2. **Mejores resultados por tienda:** ¿Cuál es la tienda que vende más?
3. **Virtual vs Fisico:** ¿Cómo son las ventas según el canal?
4. **Productos estrella:** ¿Qué productos roto más y me generan mayor utilidad?
5. **Lead Time general:** ¿Cómo se comporta el leadtime de los pedidos del canal virtual?
6. **Clasterización del LeadTime:** ¿El promedio de tiempo de pedidos es la única medida a tomar en cuenta?
7. **Repetición del cliente:** ¿Pedidos al año por cliente?
8. **Clasterización de clientes:** ¿Cuantos clientes realizan más de una compra anual?
9. **Dolar vs Otros:** ¿Como evaluo las ventas bajo la moneda de pago o bajo una moneda estándar?
10. **Canal de entrada vs canal de ventas:** ¿Cuál es el impacto del tipo de canal en las ventas generales?

## Limpieza de Datos
1. Validar Datos null
```sql
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
--Resultado=Todo OK
```
2. Validar  que cada tienda usa solo un tipo de moneda o varios
```sql
SELECT StoreKey,
        COUNT(DISTINCT Currency) AS number_currency
FROM Sales
GROUP BY StoreKey
ORDER BY number_currency DESC;
---Resultado=Solo la tienda virtual acepta diferentes tipos de moneda y todas las tiendas físicas reciben solo un tipo de moneda.
```
3. Validar si hay pedidos no entregados de tiendas virtuales o si en tiendas físicas se han hecho envios de delivery
```sql
--3.1 Tienda virtual
SELECT *
FROM Sales
WHERE Delivery_Date IS NULL AND StoreKey='0';
--Resultado=Todo OK
--3.2 Tienda fisica
SELECT *
FROM Sales
WHERE Delivery_Date IS NOT NULL and StoreKey<>'0';
--Resultado=Todo OK
```
4. Longitud de mis datos de tiempo
```sql
SELECT MIN(order_date) AS min,
       MAX(order_date) AS max
FROM sales;
/* Como solo se tiene hasta febrero 2021 se ignorara todo el 2021 para analizar años completos,pero como tampoco 
queremos perder esos datos, se creara una vista de tal manera que se conserve la info del 2021 */
```
5. Creación de vista usada recurrentemente
```sql
 -- Ignorar el año 2021 y añadir en la tabla de hechos el costo y precio */

CREATE VIEW sales_2 AS
SELECT s.*,
       p.Unit_Costo_USD,
       p.Unit_Price_USD
FROM sales as s
    left join Product as p
    ON p.ProductKey=s.ProductKey
    WHERE YEAR(s.Order_Date)<>2021;
```
## Análisis Exploratorio de Datos (EDA) e Insights

### 1. **Ventas Generales**: En terminos anuales,¿Como va las ventas y utilidad bruta de todo el grupo?
Para esta pregunta utilize principalmente una CTE y la función de Ventan LAG,además de funciones de formato para la parte visual.
```sql
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
```
![image](./Picture/query1.png)

**Insight**

Las ventas y costos han ido creciendo año a año a un ritmo casi simillar,y el Margen Bruto se ha mantenido entre el 58 y 59%, pero se ve un bajon marcado en el 2020 de practicamente de un 50% comparado a los resultados del 2019,habria que evaluar cual fue la causa de ese desplome,una de las hipótesis que se pueden manejar es el impacto de la Pandemia del COVID-19 pero en el dataset no tenemos datos para validar esto.

Pero a niveles anuales no se ve un desfase entre ventas - costo - utilidad bruta
que nos de una alerta con respecto al margen o con respecto a la política de costeo y de ventas.

### 2. **Mejores resultados por tienda:** ¿Cuál es la tienda que vende más?

Para esta pregunta utilize LEFT JOIN,la función de tiempo DATEDIFF y la función de ventana DENSE_RANK

```sql
--Verificamos que todas las tiendas tengan metros cuadrados
SELECT *
FROM Store
WHERE StoreKey<>'0'
and (SquareMeters is null or SquareMeters=0);
--Resultado=Todas las tiendas tienen m2 menos la tienda virtual

SELECT st.State,
       st.Country,
       DATEDIFF(YEAR,st.OpenDate,GETDATE()) AS Years,
       -- MIN(s.Order_Date) as First_Sales, para la 2da query
      -- MAX(s.Order_Date) as Last_Sales, para la 2da query
       DENSE_RANK() OVER(ORDER BY SUM(s.quantity*s.Unit_Price_USD) DESC) AS TOP_VENTAS,
       FORMAT(SUM(s.quantity*s.Unit_Price_USD),'N2') AS Ventas,
       FORMAT(SUM(s.quantity*(s.Unit_Price_USD-s.Unit_Costo_USD)),'N2') AS UtilidadB,
       ROUND(SUM(s.quantity*s.Unit_Price_USD)/MAX(st.squaremeters),3) AS Ventasxm2
FROM sales_2 AS s
    LEFT JOIN Store AS st
    ON s.StoreKey=st.StoreKey
     -- WHERE st.Country='Australia' para la 2da query
    GROUP BY st.State,st.Country,st.OpenDate
    ORDER BY Ventasxm2 DESC;
    
```
![image](./Picture/query2.1.png)

**Insight Inicial**

Un buen indicador seria ver solo las ventas y fijarse en el TOP,pero tomando en cuenta que cada tienda tienen factores ambientales diferentes, ya que no es lo mismo vender en una tienda de 200 m2 con 10 trabajadores que en una tienda de 30 m2 con 3 trabajadores,por lo que una medida más justa seria usar las Ventas/m2.


Observamos que la tienda Online es la que ha tenido las mayores ventas superando a tiendas que tienen mucho más años de antigüedad,esto es un buen indicador a alto nivel de que el sector e-commerce es clave,pero lo que mas resalta es que la tienda Northen Territory Australia esta por debajo de los $20/m2,por lo que antes de sacar alguna conclusion sobre su viabilidad validaremos el estado de todo el grupo de tiendas de ese país

![image](./Picture/query2.2.png)

**Insight Final**

Se observa que todas las tiendas de Australia han tenido operaciones hasta el 2020 menos la tienda Northern Territory que solo ha tenido ventas hasta Abril del 2016 por lo que eso justificaria porque sus ventas/m2 son tan bajas, por lo que habría que preguntar si ese punto de venta sigue realmente activo o es una tienda que cerro operaciones o mapear que paso con el registro de sus ventas antes de dar una conclusión con respecto a su operatividad .

Pero en general la conclusion que si podemos llegar es que las ventas online son clave,ya que venden más que cualquier tienda fisica por lo que es una primera señal para manejar la idea de impulsar con más recursos para ese canal de venta

### 3. **Virtual vs Fisico:** ¿Cómo son las ventas según el canal?
Para responder esta pregunta utilizamos CASE WHEN y funciones de ventana aplicadas junto a funcione de agregación como SUM()

```sql
SELECT CASE WHEN StoreKey='0' THEN 'Virtual' ELSE 'Fisica' END AS Tipo_tienda,
       DATETRUNC(YEAR,order_date) AS year_date,
       SUM(quantity*Unit_Price_USD) AS Ventas,
       FORMAT(CAST(SUM(quantity*Unit_Price_USD) AS numeric)/SUM(SUM(quantity*Unit_Price_USD)) OVER(PARTITION BY DATETRUNC(YEAR,order_date) ),'P2') as porc_Ventas
FROM sales_2
GROUP BY CASE WHEN StoreKey='0' THEN 'Virtual' ELSE 'Fisica' END,
         DATETRUNC(YEAR,order_date)
ORDER BY Tipo_tienda DESC,year_date ASC
```
![image](./Picture/query3.png) 

**Insight**

Se observa que en el 2016 las ventas virtuales representaban solo el 16.8% de las ventas anuales pero cerro el 2020 representando el 22.3%,ese aumento de practicamente 6 puntos porcentuales da indicio de que existe una tendencia al aumento constante de ventas por el canal virtual,lo que vuelve a reforzar la idea
de impulsar más ese canal.

### 4. **Productos estrella:** ¿Qué productos roto más y me generan mayor utilidad?
Para poder realizar esta pregunta usamos dos vistas para mejorar la lectura del código,
y funciones de ventana con rangos acumulaticos sobre la funcion SUM() y al final la función
INTERSECT para hallar la respuesta
```sql
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
```
![image](./Picture/query4.1.png) 

**Insight Inicial 1**

De los 2592 skus que en algun momento se han vendido,solo 42 engloban el 10% de las ventas globales por lo que estos son los productos clave a nivel de rotación que no deberian faltar en todas las tiendas ,asi que se deberia revisar si existen inventarios de seguridad de acuerdo para evitar quiebres de stock.

Un análisis más profundo sería validar por cada pais que productos son los de mayor rotación y enfocarse en su disponibilidad en las tiendas de cada pais,eso se podría hacer en un 2do nivel de análisis porque que un producto sera de alta rotación no significa que lo sea en todas las tiendas.
```sql
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
```
![image](./Picture/query4.2.png) 

**Insight Inicial 2**

De los 2592 skus que se han vendido solo 11 skus engloban el 10% de la Utilidad Bruta de forma histórica,por lo que si realizamos un cruce con los de alta rotacion, encontaremos los productos clave tanto en movimiento como en rotación que serian nuestros productos estrella.
```sql
SELECT * FROM
Product
WHERE ProductKey in 
(
SELECT ProductKey
FROM top_movimiento
WHERE Acumulado2<0.1

INTERSECT   --Queremos aquellos skus que son de alta rotación y de alta utilidad

SELECT ProductKey
FROM top_utilidad
WHERE Acumulado2<0.1);
```
![image](./Picture/query4.3.png) 

**Insight Final**

Podemos ver que nos sale 7 skus clave pero en si son solo 2 productos solo que en diferente presentacion de colores,por lo que en un análisis más profundo se podria ver cuanto influye el color en la venta de un mismo producto.
Igualmente se recomienda realizar el análisis a nivel de cada pais para poder observar el comportamiento real de cada grupo de tiendas por país.

### 5. **Lead Time general:** ¿Cómo se comporta el leadtime de los pedidos del canal virtual?

Para esta pregunta usamos una CTE y funciones de agregación como MAX,AVG y SUM
```sql
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
```
![image](./Picture/query5.png) 

**Insight**

Se ve que el promedio de dias de entrega ha pasado de 7 dias en el 2016 a 4 dias a partir del 2018 en adelante,lo cual es una reducción considerable y es una buena señal de que el servicio de envio ha ido mejorando a través de los años,pero también se ve que hay casos donde el tiempo ha sido hasta de 17 o 13 dias por lo que para validar la mejora del envio año tras año se realizará un análisis más profundo a continuación.

### 6. **Clasterización del LeadTime:** ¿El promedio de tiempo de pedidos es la única medida a tomar en cuenta?
Para esta pregunta usamos una CTE,CASE WHEN para poder clasificar los pedidos y funciones de ventana LAG para un comparativo con el año anterior
```sql
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
```
![image](./Picture/query6.png) 

**Insight**


Se observa que los pedidos de Tipo C que demoraban de 10 a más han ido disminuyendo año tras año,tanto si lo vemos como una comparación con el año pasado(exceptuando el 2020 que fue un año atípico) como una comparación de los pedidos anuales generales (pasando de representar el 17% de los pedidos en el 2016 ha representar menos del 1% a partir del 2019 en adelante) , por lo que se valida que se esta mejorando el tiempo de envios año tras año,un análisis mas profundo sería ver la causa de esas demoras
tal vez se terceriza el transporte o el despacho demora mucho,pero el dataset no da información para poder comprobar dichas premisas.

### 7. **Repetición del cliente:** ¿Pedidos al año por cliente?
Para esta pregunta se usa un CTE y funciones de Formato en su mayoria
```sql
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
```
![image](./Picture/query7.png) 

**Insight**

Se puede ver que apesar de los pedidos han ido aumentando año a año la frecuencia de compras nunca ha pasado de 1.5;por lo que es una señal de que a nivel global la mayoria de clientes no repiten compras en el mismo año,esto podria ser un sintoma de que el negocio no tiene una cultura de retención de clientes o por la naturaleza de sus productos es complicado generar una retención,igualmente esta en una vista general por lo que hay que hacer un análisis más profundo antes de decir formalmente que no hay una buena retención de clientes

### 8. **Clasterización de clientes:** ¿Cuantos clientes realizan más de una compra anual?
Para esta pregunta se utilizo una CTE,CASE WHEN para clasificar el tipo d cliente y funcion de ventana
a una funcion SUM()
```sql
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
```
![image](./Picture/query8.png) 

**Insight**

Se habia visto que de forma global el número de pedidos por cliente no pasaban los 1.5 pedidos pero ahora a la clasterización se le añade una clasificación podemos ver que los clientes que han hecho entre 3-5 pedidos anuales han ido aumentando cada año pasando de ser solo 19 clientes en el 2016 a ser 478 en el 2019 y 92  en el 2020,ya vimos que 2020 tuvo una caida atípica ,de forma porcental se puede ver que iniciamos con que un 0.7% de los clientes hacian entre 3 a 5 compras en el 2016 y en el 2019 el 7.3% de clientes hicieron entre 3-5 compras,y otra cosa en el 2019 fue el 1er año donde aparecio el grupo de clientes que hace más de 6 pedidos,solo fueron 4 clientes pero es un inicio de que la retención esta aumentando a un ritmo bajo que hace que si se mira de forma global no se perciba mucho,pero si hay una mejora en la retencion,leve pero la hay.

### 9. **Dolar vs Otros:** ¿Como evaluo las ventas bajo la moneda de pago o bajo una moneda estándar?
Para esta consulta se usaron CTE,funcione de Venta como LAG y ABS ,además de funciones de formato
para facilitar la visualización

```sql
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
```
![image](./Picture/query9.png) 

**Insight**


Hay 11 registros donde si se comparan las ventas con respecto al año anterior usando la moneda local,el aumento difiere considerablemente del aumento si se compara usando la moneda Dolar ,casi en un 10% extra de aumento de ventas, y tomando en cuenta que  mis costos y precios de productos estan en dolar,lo mejor seria evaluarlo todo en dolar y de esta manera evitar estos casos donde hay un aumento artificial de ventas que se podría deber principalmente al tipo de cambio fluctuante ,esta decisión es crucial a la hora de evaluar el rendimiento de vendedores , aumento de ventas generales o el tema de comisiones a vendedores.

### 10. **Canal de entrada vs canal de ventas:** ¿Cuál es eli mpacto del tipo de canal en las ventas generales?
Para esta pregunta usaremos CASE WHEN,CTEs,funciones de Venta Row_number,Joins y funciones de Formato
```sql
---Hay clientes que han hecho compras online y en tienda presencial
SELECT CustomerKey,
       COUNT(DISTINCT CASE WHEN StoreKey='0' then 1 else 2 end ) numero_tiendas
FROM sales_2
GROUP BY CustomerKey
ORDER BY numero_tiendas DESC
/*
Debido a que nuestra fecha de venta solo llega a nivel de dia y no horas ,puede que haya clientes que su primera fecha de compra tiene ventas en tiendas fisicas y virtuales
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
/* Solo sale un cliente con ese caso especial,la solucion más facil seria evaluar sus ventas si son representativas y eliminarla, pero mejor trabajamos bajo la premisa de que pueden repetirse más casos como estos en el futuro y se dará prioridad primero al canal virtual,no se puede usar el numero de orden de pedido porque no sabemos que logica tiene para ser armado la digitacion de este
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
```
![image](./Picture/query10.png) 

**Insight Inicial**

***Canal de entrada fisico***

En el año 2016, de todos los pedidos realizados por los clientes que ingresaron por el canal físico,apenas el 1.48% de esos pedidos fueron para el canal virtual,y para el 2019 y 2020 ese porcentaje paso al 14% y 18%,pero hay que entender que para el 2019 y 2020 esos valores engloban a todos los clientes que han ingresado desde el 2016 hasta la fecha por el canal fisico,y que de todas sus compras realizadas anualmente,el 14% y 17% fueron al canal virtual,

Por lo que se puede ver que los clientes que ingresan por el canal fisico,un % de sus ventas pasan al canal virtual pero a pesar del efecto acumulado el porcentaje maximo llega al 17%,lo cual no da una fuerte señal de que el canal fisico apoye al canal virtual.

***Canal de entrada virtual***


En el año 2016,de todos los pedidos realizados por clientes que ingresaron por canal virtual,el 6% de sus pedidos pasaron al canal físico y para el 2019 aumenta a casi 50%(su pico) y en el 2020 represento el 39% ,ambos números son mucho mayores al 6%,pero hay que tener encuenta el efecto acumulado otra vez,por lo que la conclusión que se podria dar es que hay un  indicio de que el canal virtual apoya a que las ventas en el canal físico aumenten.
Pero para poder reforzar esa idea habria que revisarlo más a detalle

**Impacto del tipo de canal en las ventas generales a detalle**


Se quiere medir el impacto anual de los clientes nuevos en ese año,claro que hay clientes que ingresaron al inicio,mediados
o fin de año y que tuvieron poco tiempo para probar el otro canal,pero ese ya seria un análisis más profundo que por el momento no se tocará
ya que la idea es ver el impacto entre canales y como son afectados.

```sql
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

```
![image](./Picture/query10.1.png) 

**Insight Final**

***Canal de entrada fisico***
En el 2016,solo el 1.48% de las ventas totales de clientes nuevos del canal fisico fue para el canal virtual,y en el 2018 y 2019 los valores fueron de 3.9% y 5.7% por lo que se puede ver un crecimiento de practicamente 1% anualmente;lo cual nos da la idea de que los clientes nuevos que ingresan al canal físico durante ese año por lo menos el 90% de sus ventas se quedan en el canal físico y no se ve un cambio al canal digital realmente representativo.

***Canal de entrada Virtual***
Ahora se puede el impacto anual de clientes que ingresan anualmente por el canal virtual y se ve que el impacto explicado anteriormente de más del 30% es por un factor acumulado de antiguedad del cliente, pero en el 2018 y 2019 paso de un 6% inicial del 2016 a valores de 13.8% y 17.6% lo cual si es un aumento considerable de que los clientes nuevos estan empezando a conocer el canal fisico gracias al canal virtual,en el 2020 el % bajo al 7% pero hay que tener encuenta que fue un año atípico.

Por lo que si se ve un impacto en el canal fisico gracias al canal virtual pero no es tan grande,el impacto grande viene gracias al efecto acumulado de clientes antiguos,pero no deja de ser una idea interesante,ya que mientras mas clientes ingresan por el canal virtual de manera historica sus ventas tienden a aumentar en el canal fisico.
Por  lo que refuerza la idea de impulsar el canal virtual no solo afecta sus ventas sino tambien las del canal fisico de forma acumulada.

### Conclusion

- Este análisis brindó información relevante sobre las ventas de la empresa **Mtec** que servirá para la planificación de objetivos del proximo periodo

- Uno de los descubrimientos principales fue que el canal virtual presenta las mayores ventas si se compara individualmente con las tiendas fisicas y no es el punto de venta más antiguo.

- Se detecto que en hay skus que son idénticos pero solo cambia el color,en futuros análisis hay que ver que tanto influye el color en su venta

- Se vio que los clientes que ingresan por el canal virtual, a lo largo del tiempo,empiezan a pasar sus ventas del canal virtual al canal físico en un % considerable,y refuerza la idea de que el canal virtual llega a clientes que terminan en el canal físico.

- La empresa debe impulsar el canal virtual,comenzando con disminuir el tiempo de entrega de pedidos
que actualmente es de en promedio 4 dias y manejar la posibilidad de comenzar con políticas de entrega en menos de 24 horas.

- La empresa debe desarrollar una cultura de retención de clientes,ya que se vio una mejora en la cantidad de pedidos anuales por cliente,pero si las gerencias pertinentes actúan esa retención puede mejorar.

- La empresa debe notificar a las tiendas que manejan sus ventas en otras monedas que no son Dolar,que sus resultados general y por vendedor deberan ser presentados en la moneda dolar,para que se puedan comparar todas las tiendas.


