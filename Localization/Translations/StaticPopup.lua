---@type l10n
local l10n = QuestieLoader:ImportModule("l10n")

local staticPopup = {
    -------------------------------------------------------------------------------------------
    -- QuestEventHandler - StaticPopup_Show hook - "DELETE_ITEM" Static Popup
    ["Quest Item %%s might be needed for the quest %%s. \n\nAre you sure you want to delete this?"] = {
        ["ptBR"] = "O item de missão %%s pode ser necessário para a missão %%s. \n\nTem certeza de que deseja excluir isso?",
        ["ruRU"] = "Предмет %%s может понадобиться для задания %%s. \n\nВы уверены, что хотите удалить его?",
        ["deDE"] = "Questgegenstand %%s wird für die Quest %%s benötigt. \n\nMöchtest du ihn wirklich löschen?",
        ["koKR"] = "퀘스트 아이템 %%s 가 %%s 수행을 위해 필요할 수 있습니다. \n\n그래도 해당 아이템을 파괴하시겠습니까?",
        ["esMX"] = "El objeto de misión %%s podría ser necesario para la misión %%s. \n\n¿Estás seguro de que quieres eliminarlo?",
        ["enUS"] = true,
        ["zhCN"] = false,
        ["zhTW"] = "物品 %%s 可能是任務 %%s 會用到。 \n\n是否確定要刪除?",
        ["esES"] = "El objeto de misión %%s podría ser necesario para la misión %%s. \n\n¿Estás seguro de que quieres eliminarlo?",
        ["frFR"] = "L'objet de quête %%s pourrait être nécessaire pour la quête %%s. \n\nÊtes-vous sûr de vouloir supprimer cela ?",
    },
    -------------------------------------------------------------------------------------------
    -- GameVersionError - "QUESTIE_VERSION_ERROR" Static Popup
    ["Questie-335 did not load correctly."] = {
        ["ptBR"] = "Questie-335 não carregou corretamente.",
        ["ruRU"] = "Questie-335 загрузился некорректно.",
        ["deDE"] = "Questie-335 wurde nicht korrekt geladen.",
        ["koKR"] = "Questie-335가 올바르게 로드되지 않았습니다.",
        ["esMX"] = "Questie-335 no se cargó correctamente.",
        ["enUS"] = true,
        ["zhCN"] = "Questie-335 未正确加载。",
        ["zhTW"] = "Questie-335 未正確載入。",
        ["esES"] = "Questie-335 no se cargó correctamente.",
        ["frFR"] = "Questie-335 ne s'est pas chargé correctement.",
    },
    ["The AddOns folder name is likely wrong."] = {
        ["ptBR"] = "O nome da pasta AddOns provavelmente está errado.",
        ["ruRU"] = "Вероятно, имя папки AddOns указано неверно.",
        ["deDE"] = "Der Name des AddOns-Ordners ist wahrscheinlich falsch.",
        ["koKR"] = "AddOns 폴더 이름이 잘못된 것 같습니다.",
        ["esMX"] = "El nombre de la carpeta AddOns probablemente es incorrecto.",
        ["enUS"] = true,
        ["zhCN"] = "AddOns 文件夹名称可能不正确。",
        ["zhTW"] = "AddOns 資料夾名稱可能不正確。",
        ["esES"] = "El nombre de la carpeta AddOns probablemente es incorrecto.",
        ["frFR"] = "Le nom du dossier AddOns est probablement incorrect.",
    },
    ["Rename the folder to Questie-335"] = {
        ["ptBR"] = "Renomeie a pasta para Questie-335",
        ["ruRU"] = "Переименуйте папку в Questie-335",
        ["deDE"] = "Benenne den Ordner in Questie-335 um",
        ["koKR"] = "폴더 이름을 Questie-335로 바꾸세요",
        ["esMX"] = "Cambia el nombre de la carpeta a Questie-335",
        ["enUS"] = true,
        ["zhCN"] = "将文件夹重命名为 Questie-335",
        ["zhTW"] = "將資料夾重新命名為 Questie-335",
        ["esES"] = "Cambia el nombre de la carpeta a Questie-335",
        ["frFR"] = "Renommez le dossier en Questie-335",
    },
    ["so WoW loads Questie-335.toc."] = {
        ["ptBR"] = "para que o WoW carregue Questie-335.toc.",
        ["ruRU"] = "чтобы WoW загрузил Questie-335.toc.",
        ["deDE"] = "damit WoW Questie-335.toc lädt.",
        ["koKR"] = "WoW가 Questie-335.toc를 로드하도록 하세요.",
        ["esMX"] = "para que WoW cargue Questie-335.toc.",
        ["enUS"] = true,
        ["zhCN"] = "以便 WoW 加载 Questie-335.toc。",
        ["zhTW"] = "讓 WoW 載入 Questie-335.toc。",
        ["esES"] = "para que WoW cargue Questie-335.toc.",
        ["frFR"] = "afin que WoW charge Questie-335.toc.",
    },
    ["Do not rename Questie-335.toc"] = {
        ["ptBR"] = "Não renomeie Questie-335.toc",
        ["ruRU"] = "Не переименовывайте Questie-335.toc",
        ["deDE"] = "Benenne Questie-335.toc nicht um",
        ["koKR"] = "Questie-335.toc의 이름을 바꾸지 마세요",
        ["esMX"] = "No cambies el nombre de Questie-335.toc",
        ["enUS"] = true,
        ["zhCN"] = "不要重命名 Questie-335.toc",
        ["zhTW"] = "不要重新命名 Questie-335.toc",
        ["esES"] = "No cambies el nombre de Questie-335.toc",
        ["frFR"] = "Ne renommez pas Questie-335.toc",
    },
    ["to Questie.toc."] = {
        ["ptBR"] = "para Questie.toc.",
        ["ruRU"] = "в Questie.toc.",
        ["deDE"] = "in Questie.toc.",
        ["koKR"] = "Questie.toc로.",
        ["esMX"] = "a Questie.toc.",
        ["enUS"] = true,
        ["zhCN"] = "为 Questie.toc。",
        ["zhTW"] = "為 Questie.toc。",
        ["esES"] = "a Questie.toc.",
        ["frFR"] = "en Questie.toc.",
    },
    -------------------------------------------------------------------------------------------
    -- Add new Static Popup translations below. Please reference where it's located.
}

for k, v in pairs(staticPopup) do
    l10n.translations[k] = v
end
