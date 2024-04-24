module koinobori::koinobori {
    use sui::tx_context::{Self, sender, TxContext};
    use std::string::{utf8, String};
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::object_table::{Self, ObjectTable};
    use sui::package;
    use sui::display;

    struct Koi has key, store {
        id: UID,
        number: u16,
    }

    struct Nobori has key {
        id: UID,
        koi_collection: ObjectTable<u16, Koi>,
    }
}