select * from netflix_df where show_id='s5023';

drop TABLE [dbo].[netflix_df]

delete from [dbo].[netflix_df];

CREATE TABLE [dbo].[netflix_df](
	[show_id] [varchar](10) primary key,
	[type] [varchar](10) NULL,
	[title] [nvarchar](200) NULL,
	[director] [varchar](300) NULL,
	[cast] [varchar](1000) NULL,
	[country] [varchar](150) NULL,
	[date_added] [varchar](20) NULL,
	[release_year] [int] NULL,
	[rating] [varchar](10) NULL,
	[duration] [varchar](10) NULL,
	[listed_in] [varchar](100) NULL,
	[description] [varchar](500) NULL)

	alter table netflix_df add constraint pk_show_id primary key (show_id)
	alter table netflix_df alter column show_id not null;

-- check for duplicates and remove it
select show_id,count(*) from netflix_df group by show_id having count(*)>1;

select * from netflix_df where (title) in (
select (title) from netflix_df group by (title) having count(*)>1) order by title;

select * from netflix_df where concat((title),type) in (
select concat((title),type) from netflix_df group by (title),type having count(*)>1) order by title,type;
-- removed duplicates
with cte as(
select *,row_number() over(partition by title,type order by show_id) as rn from netflix_df)

delete from cte where rn!=1; 

-- keep comma separted values in different tables i.e director, cast, listed_in, country
-- segregated based on , and trim it as it has white spaces and store in a table
select show_id,trim(value) as director into netflix_directors from netflix_df cross apply string_split(director,',')
select *  from netflix_directors order by 1;
-- do the same for other multi value columns
select show_id,trim(value) as genre into netflix_genre from netflix_df cross apply string_split(listed_in,',')
select show_id,trim(value) as country into netflix_country from netflix_df cross apply string_split(country,',')
select show_id,trim(value) as cast into netflix_cast from netflix_df cross apply string_split(cast,',')

-- date conversion and ignore the columns where we have sepate tables, get it from cte or netflix_df as the duplicates are already removed from main table

with cte as(
select *,row_number() over(partition by title,type order by show_id) as rn from netflix_df)

select show_id,type,title,cast(date_added as date) as date_added,release_year,
rating,duration,description from cte -- netflix_df

-- check for  missing values in python
/*show_id            0
type               0
title              0
director        2634
cast             825
country          831
date_added        10
release_year       0
rating             4
duration           3
listed_in          0
description        0
*/
-- update missing values of country 
select * from netflix_df where country is null; -- 831 rows
-- used group by to get unique combination of directory,country as the same director can directed many movies in same country or multiple countries

select director,country from netflix_directors nd,netflix_country nc where nd.show_id=nc.show_id group by country,director order by director
--  Janusz Majewski has empty country 
select nd.show_id,director,country from netflix_directors nd,netflix_country nc where nd.show_id=nc.show_id order by country desc
-- Janusz Majewski  Poland for s7008
select * from netflix_df where show_id='s7008'
-- populated 194 missing show ids from main table to country table where country is null
insert into netflix_country
select show_id,m.country from netflix_df nr inner join  (
select director,country from netflix_directors nd,netflix_country nc where nd.show_id=nc.show_id group by country,director) m
on nr.director=m.director where nr.country is null;

select * from netflix_df where duration is null;
--rating has duration , so assign duration as rating wher it is null

--select format(release_year,'yyyy') from netflix
--drop table dates
-- select  cast(concat('01-01-',release_year) as date) as date_added  into dates from netflix where date_added is null;


with cte as(
select *,row_number() over(partition by title,type order by show_id) as rn from netflix_df)

select show_id,type,title,
(case when date_added is null then cast((concat('01-01-',release_year)) as date) else cast(date_added as date) end) as date_added,release_year,
(case when rating is null then 'No Rating' else rating end) as rating,
(case when duration is null then rating else duration end) as duration,description into netflix from cte

--Cleaning of table completes *****************************************************************************************************
-- Analysis starts


/*1  for each director count the no of movies and tv shows created by them in separate columns 
for directors who have created tv shows and movies both */

select director,count(distinct type) as distinct_types from netflix n, netflix_directors nd where n.show_id=nd.show_id 
group by director order by distinct_types desc
-- 83 directors have created both Movie and TV shows
select director,count(distinct type) as distinct_types from netflix n, netflix_directors nd where n.show_id=nd.show_id 
group by director having count(distinct type)>1

-- count movies_total and tv_shows total
select director,count(distinct case when type='Movie' then  n.show_id end) as movies_count,
count(distinct case when type='TV Show' then  n.show_id end) as tv_shows_count 
from netflix n ,netflix_directors nd -- netflix n1
where n.show_id=nd.show_id -- and n.show_id=n1.show_id and n.type='Movie' and n1.type='TV Shows' 
group by director having count(distinct type)>1

-- select * from netflix
--2 which country has highest number of comedy movies 
select top 1 country,count(distinct ng.show_id) movies_count 
from netflix_country nc,netflix_genre ng,netflix n 
where nc.show_id=ng.show_id and ng.genre='Comedies' and n.show_id=ng.show_id and n.type='Movie' group by country  order by movies_count desc;


--3. hightes moves count in each country
with cte as (
select country,count(distinct ng.show_id) movies_count from netflix_country nc,netflix_genre ng where nc.show_id=ng.show_id and ng.genre='Comedies' group by country)
select * from (
select *,row_number() over(partition by country order by movies_count desc) as rn from cte) A
 where rn=1

select * from netflix 

-- 4.for each year (as per date added to netflix), which director has maximum number of movies released
with cte as (
select director,year(date_added) as released_year , count(distinct n.show_id) as movies_count 
from  netflix n, netflix_directors nd 
where nd.show_id=n.show_id and type='Movie' group by director,year(date_added)) -- order by count(distinct n.show_id) desc
select * from ( -- , cte2 as (
select *,row_number() over(partition by released_year order by movies_count desc, director) as rn from cte ) A where rn=1

-- select * from cte2 where rn=1

-- we have a tie in the movies count of year so getting multiple ranks, hence sort it further by director based on alphabetical order

-- 5.  what is average duration of movies in each genre
select genre from netflix_genre where genre like '%Comedi%'

select genre,avg(cast(replace(duration,' min','') as int)) avg_duration from netflix n, netflix_genre ng
where n.show_id=ng.show_id and type='Movie' group by genre

--5  find the list of directors who have created horror and comedy movies both  
-- display director names along with number of comedy and horror movies directed by them
--  group all three tables, filter horror and comedy movies and filter whose genre count is greater than 1 for both genres

select director,count(distinct genre) genre_count from netflix n, netflix_directors nd, netflix_genre ng  
where n.show_id=nd.show_id and n.show_id=ng.show_id 
and genre in ('Horror Movies','Comedies') and type='Movie'
group by director  having count(distinct genre)>1  -- order by genre_count desc 

select director,
count(case when genre='Horror Movies' then n.show_id end) comedy_movie_count,
count(case when genre='Comedies' then n.show_id end) horrow_movie_count                                                                      
from netflix n, netflix_directors nd, netflix_genre ng  
where n.show_id=nd.show_id and n.show_id=ng.show_id 
and genre in ('Horror Movies','Comedies') and type='Movie'
group by director  having count(distinct genre)=2  -- order by genre_count desc 

