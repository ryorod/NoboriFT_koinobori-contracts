module koinobori::role {
    // === Errors ===

    const EAdminCapExpired: u64 = 1;

    // === Structs ===

    public struct ROLE has drop {}

    public struct AdminCap has key {
        id: UID,
        epoch: u64,
    }

    public struct MasterAdminCap has key, store {
        id: UID,
    }

    // === Init Function ===

    fun init(
        _otw: ROLE,
        ctx: &mut TxContext,
    ) {
        let master_admin_cap = MasterAdminCap{
            id: object::new(ctx)
        };

        let admin_cap = create_admin_cap(ctx);

        transfer::transfer(master_admin_cap, ctx.sender());
        transfer::transfer(admin_cap, ctx.sender());
    }

    // === Public-Mutative Functions ===

    entry fun grant_admin_cap(
        _: &MasterAdminCap,
        receiver: address,
        ctx: &mut TxContext,
    ) {
        let admin_cap = create_admin_cap(ctx);
        transfer::transfer(admin_cap, receiver)
    }

    public fun revoke_admin_cap(
        cap: AdminCap,
    ) {
        let AdminCap { id, epoch: _ } = cap;
        object::delete(id);
    }

    // === Public-Package Functions ===

    public(package) fun verify_admin_cap(
        cap: &AdminCap,
        ctx: &TxContext,
    ) {
        assert!(cap.epoch == ctx.epoch(), EAdminCapExpired);
    }

    // === Private Functions ===

    fun create_admin_cap(
       ctx: &mut TxContext, 
    ): AdminCap {
        let admin_cap = AdminCap {
            id: object::new(ctx),
            epoch: ctx.epoch(),
        };

        admin_cap
    }
}