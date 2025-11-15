--!strict

type SlotId = string

type SlotData = {
    [string]: any,
}

type SlotMeta = {
    displayName: string?,
    level: number?,
    lastPlayed: number?,
    playTime: number?,
    createdAt: number?,
    [string]: any,
}

type AccountData = {
    [string]: any,
}

type DocumentSlot = {
    data: SlotData,
    meta: SlotMeta,
}

type DocumentSession = {
    token: string,
    lastSeen: number,
}

type Document = {
    version: number,
    createdAt: number,
    updatedAt: number,

    account: AccountData,

    slots: {
        [SlotId]: DocumentSlot,
    },

    activeSlot: SlotId?,
}

export type MiddlewareContext = {
    store: SlotStore?,
    player: Player?,
    userId: number,
    slotId: SlotId?,
}

export type MiddlewareFn = (ctx: MiddlewareContext, ...any) -> ()

export type MiddlewareConfig = {
    beforeLoad: { MiddlewareFn }?,
    afterLoad: { MiddlewareFn }?,
    beforeSave: { MiddlewareFn }?,
    afterSave: { MiddlewareFn }?,
}

export type MigrationFn = (doc: Document) -> ()

type SlotConfig = {
    dataStoreName: string?,
    scope: string?,

    maxSlots: number,
    slotTemplate: SlotData,

    accountTemplate: AccountData?,
    defaultMeta: SlotMeta?,

    middleware: MiddlewareConfig?,
    migrations: { [number]: MigrationFn }?,
    sessionTTL: number?,

    autoSaveInterval: number?,
    saveOnLeave: boolean?,
    saveOnTeleport: boolean?,

    allowedSlotIds: { SlotId }?,

    version: number?,
}

type AdapterResult<T> = {
	ok: boolean,
	value: T?,
	error: string?,
}

type SlotSummary = {
    id: SlotId,
    exists: boolean,
    meta: SlotMeta?,
}

type SlotHandle = {
    Id: SlotId,
    Data: SlotData,
    Meta: SlotMeta,

    SaveAsync: (self: SlotHandle) -> AdapterResult<nil>,
    Release: (self: SlotHandle) -> (),
}

type SlotStore = {
    Name: string,

    ListSlotsAsync: (self: SlotStore, userId: number) -> AdapterResult<{ SlotSummary }>,
    LoadSlotAsync: (self: SlotStore, player: Player, slotId: SlotId, opts: { createIfMissing: boolean }?) -> AdapterResult<SlotHandle>,
    SwitchSlotAsync: (self: SlotStore, player: Player, slotId: SlotId, opts: { createIfMissing: boolean }?) -> AdapterResult<SlotHandle>,

    GetLoadedSlot: (self: SlotStore, player: Player) -> SlotHandle?,
    GetDocumentAccount: (self: SlotStore, player: Player) -> AccountData?,
    DebugPeekDocumentAsync: (self: SlotStore, userId: number) -> AdapterResult<Document>,

    SavePlayerAsync: (self: SlotStore, player: Player) -> AdapterResult<nil>,
    DeleteSlotAsync: (self: SlotStore, userId: number, slotId: SlotId) -> AdapterResult<nil>,
    FlushAndLockAsync: (self: SlotStore, userId: number) -> AdapterResult<nil>,

    SlotLoaded: any,
    SlotReleased: any,
    SlotDeleted: any,
    PlayerDocumentLoaded: any,
    PlayerDocumentReleased: any,

    SlotSaved: any,
}

return {}
