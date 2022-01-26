connect / as sysdba

drop user usr_02          cascade;
drop user usr_01          cascade;
drop user org_data        cascade;
drop user the_dba         cascade;


drop role    rol_org_data_admin;
drop context ctx_org_data;

create user the_dba  identified by secretGarden default tablespace data temporary tablespace temp quota unlimited on data;

grant dba to the_dba;

connect the_dba/secretGarden

create user usr_01   identified by secretGarden default tablespace data temporary tablespace temp quota unlimited on data;
create user usr_02   identified by secretGarden default tablespace data temporary tablespace temp quota unlimited on data;
create user org_data identified by secretGarden default tablespace data temporary tablespace temp quota unlimited on data;

create role rol_org_data_admin;

grant
   create any context,
   create     procedure,
   create     sequence,
   create     session,
   create     table 
to
   org_data;

--
-- the_dba cannot grant execute on dbms_random
--
connect / as sysdba
grant execute on dbms_random to org_data;
connect the_dba/secretGarden

--

grant
   create session
to
   usr_01;

grant
   create session,
   create table,
   create procedure
to
   usr_02;

connect org_data/secretGarden

create table tab_p (
   id   integer          generated by default on null as identity,
   tx   varchar2(20)     not null,
   nm   number               null,
   --
   constraint tab_p_pk primary key(id),
   constraint tab_p_uq unique     (tx)
);


create table tab_c (
   id_p                not null,
   val_1  varchar2(2)  not null check (val_1 in ('A', 'B', 'C', 'AA', 'BB', 'CC')),
   val_2  number       not null,
   --
   constraint tab_c_fk foreign key (id_p) references tab_p
);


insert into tab_p (tx, nm) values ('five' , 5);
insert into tab_p (tx, nm) values ('four' , 4);
insert into tab_p (tx, nm) values ('seven', 7);
insert into tab_p (tx, nm) values ('eight', 8);

create package modif_tab as

    procedure insert_c (tx_ varchar2, val_1_ varchar2, val_2_ number);

end modif_tab;
/


create package body modif_tab as

    procedure insert_c (tx_ varchar2, val_1_ varchar2, val_2_ number) is
    begin

        insert into tab_c(id_p, val_1, val_2)
        select
           id,
           val_1_,
           val_2_
        from
           tab_p
        where
           tx = tx_;

    end insert_c;

end modif_tab;
/


prompt call madif_tab.insert_c
begin
   modif_tab.insert_c('four' , 'AA',  5.1);
   modif_tab.insert_c('seven', 'BB', 24.7);
   modif_tab.insert_c('five' , 'CC',  8.2);
end;
/

create package usr_interface as
   procedure insert_random_data;
end;
/

create package body usr_interface as
   procedure insert_random_data is
      tx_  varchar2(20);
   begin
      tx_ := dbms_random.string('a', dbms_random.value(1, 20));
      insert into tab_p (tx, nm) values (tx_, trunc(dbms_random.value(0, 1000),2));

      modif_tab.insert_c(
         tx_,
         chr(dbms_random.value(65, 68)),
         trunc(dbms_random.value(1, 100000), 30));

   end insert_random_data;
end;
/

prompt call usr_interface.insert_random_data
begin
   dbms_random.seed(1);
   usr_interface.insert_random_data;
   usr_interface.insert_random_data;
   usr_interface.insert_random_data;
end;
/

create context ctx_org_data using org_data.ctx_pkg;

create package ctx_pkg as

    procedure set_value(value in varchar2);

end ctx_pkg;
/


create package body ctx_pkg as

    procedure set_value(value in varchar2) is
    begin
        dbms_session.set_context('ctx_org_data', 'attr', value);
    end set_value;

end ctx_pkg;
/

connect / as sysdba

grant execute on org_data.usr_interface to rol_org_data_admin;
grant rol_org_data_admin to usr_01;

connect usr_02/secretGarden

create or replace package package_with_errors as

    procedure do_something;

end package_with_errors;
/

create or replace package body package_with_errors as

    procedure do_something is
       max_num number;
    begin

       select max(num) into max_num from inexisting_table;
       dbms_output.put_line('max num is ' || max_num);

    end do_something;
end package_with_errors;
/

show errors
