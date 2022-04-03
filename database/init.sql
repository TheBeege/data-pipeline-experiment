create table tweets (
    id bigint auto_increment primary key,
    text text not null,
    username varchar(128) not null,
--     attached_image_url varchar(512) null,
    conversation_id bigint null
);
