param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "AoE4RPG.rdo"),
    [string]$LocStringOutputPath = (Join-Path $PSScriptRoot "AoE4RPG_rdo_locstrings_to_merge.csv")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:NextRdoIdentifier = [UInt64]6798700000001000000
$script:Document = New-Object System.Xml.XmlDocument

$script:ModParts = @{
    0 = "2555718439"
    1 = "1124130782"
    2 = "2856644000"
    3 = "2097256302"
}

function New-RdoIdentifier {
    $identifier = $script:NextRdoIdentifier.ToString(
        [System.Globalization.CultureInfo]::InvariantCulture
    )
    $script:NextRdoIdentifier++
    return $identifier
}

function Add-RdoScalarProperty {
    param(
        [System.Xml.XmlElement]$Owner,
        [string]$Name,
        [string]$Type,
        [AllowEmptyString()][string]$Value
    )

    $property = $script:Document.CreateElement("DataProperty")
    $property.SetAttribute("Name", $Name)
    $property.SetAttribute("Type", $Type)
    $property.SetAttribute("Value", $Value)
    [void]$Owner.AppendChild($property)
    return $property
}

function Add-RdoBareScalarProperty {
    param(
        [System.Xml.XmlElement]$Owner,
        [string]$Name,
        [string]$Type
    )

    $property = $script:Document.CreateElement("DataProperty")
    $property.SetAttribute("Name", $Name)
    $property.SetAttribute("Type", $Type)
    [void]$Owner.AppendChild($property)
    return $property
}

function Add-RdoEmptyObjectProperty {
    param(
        [System.Xml.XmlElement]$Owner,
        [string]$Name
    )

    $property = $script:Document.CreateElement("DataProperty")
    $property.SetAttribute("Name", $Name)
    $property.SetAttribute("Type", "Object")
    [void]$Owner.AppendChild($property)
    return $property
}

function New-RdoDataObject {
    param(
        [string]$Type,
        [AllowEmptyString()][string]$OwnerIdentifier = ""
    )

    $object = $script:Document.CreateElement("DataObject")
    $object.SetAttribute("Name", "")
    $object.SetAttribute("Type", $Type)
    $object.SetAttribute("Id", (New-RdoIdentifier))
    if ($OwnerIdentifier -ne "") {
        $object.SetAttribute("OwnerId", $OwnerIdentifier)
    }
    return $object
}

function Add-RdoChildObjectProperty {
    param(
        [System.Xml.XmlElement]$Owner,
        [string]$Name,
        [string]$ChildType
    )

    $property = Add-RdoEmptyObjectProperty -Owner $Owner -Name $Name
    $child = New-RdoDataObject -Type $ChildType -OwnerIdentifier $Owner.GetAttribute("Id")

    $value = $script:Document.CreateElement("DataValue")
    $value.SetAttribute("Name", $ChildType)
    $value.InnerText = $child.GetAttribute("Id")
    [void]$property.AppendChild($value)
    [void]$property.AppendChild($child)
    return $child
}

function Add-RdoLocStringProperty {
    param(
        [System.Xml.XmlElement]$Owner,
        [string]$Name,
        [int]$LocStringKey
    )

    $locString = Add-RdoChildObjectProperty `
        -Owner $Owner `
        -Name $Name `
        -ChildType "util::ReflectLocString"

    Add-RdoScalarProperty -Owner $locString -Name "m_modPart2" -Type "UInt32" -Value $script:ModParts[2] | Out-Null
    Add-RdoScalarProperty -Owner $locString -Name "m_modPart3" -Type "UInt32" -Value $script:ModParts[3] | Out-Null
    Add-RdoScalarProperty -Owner $locString -Name "m_modPart0" -Type "UInt32" -Value $script:ModParts[0] | Out-Null
    Add-RdoScalarProperty -Owner $locString -Name "m_modPart1" -Type "UInt32" -Value $script:ModParts[1] | Out-Null
    Add-RdoScalarProperty -Owner $locString -Name "m_locStringKey" -Type "Int32" -Value ([string]$LocStringKey) | Out-Null
}

function Add-RdoObjectCollection {
    param(
        [System.Xml.XmlElement]$Owner,
        [string]$Name,
        [string[]]$ChildTypes
    )

    $property = Add-RdoEmptyObjectProperty -Owner $Owner -Name $Name
    $children = @()

    foreach ($childType in $ChildTypes) {
        $child = New-RdoDataObject -Type $childType -OwnerIdentifier $Owner.GetAttribute("Id")
        $value = $script:Document.CreateElement("DataValue")
        $value.SetAttribute("Name", $childType)
        $value.InnerText = $child.GetAttribute("Id")
        [void]$property.AppendChild($value)
        $children += $child
    }

    foreach ($child in $children) {
        [void]$property.AppendChild($child)
    }
    return ,$children
}

function ConvertTo-RdoBoolean {
    param([bool]$Value)
    if ($Value) {
        return "true"
    }
    return "false"
}

function New-RdoEnumerationItem {
    param(
        [string]$Key,
        [int]$LocStringKey,
        [bool]$Default = $false
    )

    return [pscustomobject]@{
        Key = $Key
        LocStringKey = $LocStringKey
        Default = $Default
    }
}

function Add-RdoOptionObjects {
    param(
        [System.Xml.XmlElement]$Section,
        [object[]]$OptionDefinitions
    )

    $types = @($OptionDefinitions | ForEach-Object {
        if ($_.Kind -eq "Boolean") {
            "WinCondition::BooleanOptionUIDescriptor"
        } else {
            "WinCondition::EnumerationOptionUIDescriptor"
        }
    })
    $options = Add-RdoObjectCollection -Owner $Section -Name "m_options" -ChildTypes $types

    for ($optionIndex = 0; $optionIndex -lt $OptionDefinitions.Count; $optionIndex++) {
        $definition = $OptionDefinitions[$optionIndex]
        $option = $options[$optionIndex]

        Add-RdoScalarProperty -Owner $option -Name "#BaseTypes" -Type "String" -Value "WinCondition::OptionUIDescriptor#0|" | Out-Null
        Add-RdoScalarProperty -Owner $option -Name "m_key" -Type "String" -Value $definition.Key | Out-Null

        if ($definition.Kind -eq "Boolean") {
            Add-RdoScalarProperty `
                -Owner $option `
                -Name "m_defaultValue" `
                -Type "Bool" `
                -Value (ConvertTo-RdoBoolean $definition.Default) | Out-Null
        } else {
            $itemTypes = @($definition.Items | ForEach-Object {
                "WinCondition::OptionEnumItemUIDescriptor"
            })
            $items = Add-RdoObjectCollection -Owner $option -Name "m_enumItems" -ChildTypes $itemTypes

            for ($itemIndex = 0; $itemIndex -lt $definition.Items.Count; $itemIndex++) {
                $itemDefinition = $definition.Items[$itemIndex]
                $item = $items[$itemIndex]

                Add-RdoScalarProperty -Owner $item -Name "m_key" -Type "String" -Value $itemDefinition.Key | Out-Null
                Add-RdoLocStringProperty -Owner $item -Name "m_feSummaryName" -LocStringKey $itemDefinition.LocStringKey
                Add-RdoLocStringProperty -Owner $item -Name "m_feName" -LocStringKey $itemDefinition.LocStringKey
                Add-RdoScalarProperty `
                    -Owner $item `
                    -Name "m_isDefaultValue" `
                    -Type "Bool" `
                    -Value (ConvertTo-RdoBoolean $itemDefinition.Default) | Out-Null
                Add-RdoScalarProperty -Owner $item -Name "m_devOnly" -Type "Bool" -Value "false" | Out-Null
            }
        }

        Add-RdoLocStringProperty -Owner $option -Name "m_feSummaryName" -LocStringKey $definition.TitleLocStringKey
        Add-RdoLocStringProperty -Owner $option -Name "m_feDescriptionTooltip" -LocStringKey $definition.DescriptionLocStringKey
        Add-RdoLocStringProperty -Owner $option -Name "m_feName" -LocStringKey $definition.TitleLocStringKey
        # IMPORTANT: Mark every option explicitly as a non-slot option.
        # The native lobby expects this field when rendering custom options.
        Add-RdoScalarProperty -Owner $option -Name "m_isSlotOption" -Type "Bool" -Value "false" | Out-Null
    }
}

function Add-RdoOptionSection {
    param(
        [System.Xml.XmlElement]$Section,
        [string]$Key,
        [int]$TitleLocStringKey,
        [object[]]$OptionDefinitions,
        [bool]$Featured = $false
    )

    Add-RdoScalarProperty -Owner $Section -Name "m_featured" -Type "Bool" -Value $Featured.ToString().ToLowerInvariant() | Out-Null
    Add-RdoScalarProperty -Owner $Section -Name "m_key" -Type "String" -Value $Key | Out-Null
    Add-RdoOptionObjects -Section $Section -OptionDefinitions $OptionDefinitions
    Add-RdoLocStringProperty -Owner $Section -Name "m_feName" -LocStringKey $TitleLocStringKey
}

$classSlotItems = @(
    New-RdoEnumerationItem -Key "aorpg_class_slots_1" -LocStringKey 1911
    New-RdoEnumerationItem -Key "aorpg_class_slots_2" -LocStringKey 1912
    New-RdoEnumerationItem -Key "aorpg_class_slots_3" -LocStringKey 1913
    New-RdoEnumerationItem -Key "aorpg_class_slots_4" -LocStringKey 1914
    New-RdoEnumerationItem -Key "aorpg_class_slots_5" -LocStringKey 1915 -Default $true
)

$populationItems = @(
    New-RdoEnumerationItem -Key "aorpg_population_25" -LocStringKey 1950
    New-RdoEnumerationItem -Key "aorpg_population_50" -LocStringKey 1951
    New-RdoEnumerationItem -Key "aorpg_population_75" -LocStringKey 1952
    New-RdoEnumerationItem -Key "aorpg_population_100" -LocStringKey 1953
    New-RdoEnumerationItem -Key "aorpg_population_150" -LocStringKey 1954
    New-RdoEnumerationItem -Key "aorpg_population_200" -LocStringKey 1955 -Default $true
    New-RdoEnumerationItem -Key "aorpg_population_250" -LocStringKey 1956
    New-RdoEnumerationItem -Key "aorpg_population_300" -LocStringKey 1957
    New-RdoEnumerationItem -Key "aorpg_population_350" -LocStringKey 1958
    New-RdoEnumerationItem -Key "aorpg_population_400" -LocStringKey 1959
)

$victoryOptions = @(
    [pscustomobject]@{ Kind = "Boolean"; Key = "option_aorpg_victory_annihilation"; TitleLocStringKey = 1944; DescriptionLocStringKey = 1944; Default = $true }
    [pscustomobject]@{ Kind = "Boolean"; Key = "option_aorpg_victory_conquest"; TitleLocStringKey = 1943; DescriptionLocStringKey = 1943; Default = $true }
    [pscustomobject]@{ Kind = "Boolean"; Key = "option_aorpg_victory_regicide"; TitleLocStringKey = 1945; DescriptionLocStringKey = 1945; Default = $false }
)

$kingLevelMinuteItems = @(
    New-RdoEnumerationItem -Key "aorpg_king_level_minutes_1" -LocStringKey 1972
    New-RdoEnumerationItem -Key "aorpg_king_level_minutes_2" -LocStringKey 1973
    New-RdoEnumerationItem -Key "aorpg_king_level_minutes_3" -LocStringKey 1974
    New-RdoEnumerationItem -Key "aorpg_king_level_minutes_5" -LocStringKey 1975 -Default $true
    New-RdoEnumerationItem -Key "aorpg_king_level_minutes_10" -LocStringKey 1976
    New-RdoEnumerationItem -Key "aorpg_king_level_minutes_15" -LocStringKey 1977
)

$rateLocStringKeys = @{
    "game_rates_010" = 1930
    "game_rates_025" = 1931
    "game_rates_050" = 1932
    "game_rates_075" = 1933
    "game_rates_1" = 1934
    "game_rates_1_25" = 1935
    "game_rates_1_50" = 1936
    "game_rates_2" = 1937
    "game_rates_3" = 1938
    "game_rates_5" = 1939
    "game_rates_10" = 1940
    "game_rates_20" = 1941
    "game_rates_15" = 1963
    "game_rates_50" = 1964
    "game_rates_100" = 1965
    "game_rates_1_75" = 1966
    "game_rates_2_50" = 1967
    "game_rates_4" = 1968
    "game_rates_7_50" = 1969
    "game_rates_25" = 1970
}

$economyRateItems = @(
    New-RdoEnumerationItem -Key "game_rates_050" -LocStringKey $rateLocStringKeys["game_rates_050"]
    New-RdoEnumerationItem -Key "game_rates_075" -LocStringKey $rateLocStringKeys["game_rates_075"]
    New-RdoEnumerationItem -Key "game_rates_1" -LocStringKey $rateLocStringKeys["game_rates_1"] -Default $true
    New-RdoEnumerationItem -Key "game_rates_1_25" -LocStringKey $rateLocStringKeys["game_rates_1_25"]
    New-RdoEnumerationItem -Key "game_rates_1_50" -LocStringKey $rateLocStringKeys["game_rates_1_50"]
    New-RdoEnumerationItem -Key "game_rates_1_75" -LocStringKey $rateLocStringKeys["game_rates_1_75"]
    New-RdoEnumerationItem -Key "game_rates_2" -LocStringKey $rateLocStringKeys["game_rates_2"]
    New-RdoEnumerationItem -Key "game_rates_2_50" -LocStringKey $rateLocStringKeys["game_rates_2_50"]
    New-RdoEnumerationItem -Key "game_rates_3" -LocStringKey $rateLocStringKeys["game_rates_3"]
    New-RdoEnumerationItem -Key "game_rates_4" -LocStringKey $rateLocStringKeys["game_rates_4"]
    New-RdoEnumerationItem -Key "game_rates_5" -LocStringKey $rateLocStringKeys["game_rates_5"]
    New-RdoEnumerationItem -Key "game_rates_7_50" -LocStringKey $rateLocStringKeys["game_rates_7_50"]
    New-RdoEnumerationItem -Key "game_rates_10" -LocStringKey $rateLocStringKeys["game_rates_10"]
    New-RdoEnumerationItem -Key "game_rates_15" -LocStringKey $rateLocStringKeys["game_rates_15"]
    New-RdoEnumerationItem -Key "game_rates_20" -LocStringKey $rateLocStringKeys["game_rates_20"]
    New-RdoEnumerationItem -Key "game_rates_25" -LocStringKey $rateLocStringKeys["game_rates_25"]
    New-RdoEnumerationItem -Key "game_rates_50" -LocStringKey $rateLocStringKeys["game_rates_50"]
    New-RdoEnumerationItem -Key "game_rates_100" -LocStringKey $rateLocStringKeys["game_rates_100"]
)

$experienceRateItems = @(
    New-RdoEnumerationItem -Key "game_rates_010" -LocStringKey $rateLocStringKeys["game_rates_010"]
    New-RdoEnumerationItem -Key "game_rates_025" -LocStringKey $rateLocStringKeys["game_rates_025"]
    New-RdoEnumerationItem -Key "game_rates_050" -LocStringKey $rateLocStringKeys["game_rates_050"]
    New-RdoEnumerationItem -Key "game_rates_1" -LocStringKey $rateLocStringKeys["game_rates_1"] -Default $true
    New-RdoEnumerationItem -Key "game_rates_1_25" -LocStringKey $rateLocStringKeys["game_rates_1_25"]
    New-RdoEnumerationItem -Key "game_rates_1_50" -LocStringKey $rateLocStringKeys["game_rates_1_50"]
    New-RdoEnumerationItem -Key "game_rates_2" -LocStringKey $rateLocStringKeys["game_rates_2"]
    New-RdoEnumerationItem -Key "game_rates_3" -LocStringKey $rateLocStringKeys["game_rates_3"]
    New-RdoEnumerationItem -Key "game_rates_5" -LocStringKey $rateLocStringKeys["game_rates_5"]
    New-RdoEnumerationItem -Key "game_rates_10" -LocStringKey $rateLocStringKeys["game_rates_10"]
    New-RdoEnumerationItem -Key "game_rates_20" -LocStringKey $rateLocStringKeys["game_rates_20"]
)

$gameplayOptions = @(
    [pscustomobject]@{
        Kind = "Boolean"
        Key = "option_aorpg_uncapped_hero_elite_levels"
        TitleLocStringKey = 1960
        DescriptionLocStringKey = 1864
        Default = $false
    }
    [pscustomobject]@{
        Kind = "Enumeration"
        Key = "option_aorpg_max_class_slots"
        TitleLocStringKey = 1961
        DescriptionLocStringKey = 1859
        Items = $classSlotItems
    }
    [pscustomobject]@{
        Kind = "Enumeration"
        Key = "option_aorpg_human_xp_multiplier"
        TitleLocStringKey = 1978
        DescriptionLocStringKey = 1978
        Items = $experienceRateItems
    }
    [pscustomobject]@{
        Kind = "Enumeration"
        Key = "option_aorpg_ai_xp_multiplier"
        TitleLocStringKey = 1979
        DescriptionLocStringKey = 1979
        Items = $experienceRateItems
    }
    [pscustomobject]@{
        Kind = "Enumeration"
        Key = "option_aorpg_king_level_minutes"
        TitleLocStringKey = 1971
        DescriptionLocStringKey = 1971
        Items = $kingLevelMinuteItems
    }
    [pscustomobject]@{
        Kind = "Enumeration"
        Key = "option_aorpg_wall_health_multiplier"
        TitleLocStringKey = 2032
        DescriptionLocStringKey = 2033
        Items = $economyRateItems
    }
)

$resourceOptions = @(
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_map_resource_food"; TitleLocStringKey = 1902; DescriptionLocStringKey = 1902; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_map_resource_wood"; TitleLocStringKey = 1903; DescriptionLocStringKey = 1903; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_map_resource_gold"; TitleLocStringKey = 1904; DescriptionLocStringKey = 1904; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_map_resource_stone"; TitleLocStringKey = 1905; DescriptionLocStringKey = 1905; Items = $economyRateItems }
)

$playerOptions = @(
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_player_gather_speed"; TitleLocStringKey = 1962; DescriptionLocStringKey = 1861; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_player_build_speed"; TitleLocStringKey = 1906; DescriptionLocStringKey = 1906; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_player_train_speed"; TitleLocStringKey = 1907; DescriptionLocStringKey = 1907; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_player_max_population"; TitleLocStringKey = 1947; DescriptionLocStringKey = 1947; Items = $populationItems }
)

$aiOptions = @(
    [pscustomobject]@{ Kind = "Boolean"; Key = "option_aorpg_ai_keep_experience_on_death"; TitleLocStringKey = 2034; DescriptionLocStringKey = 2035; Default = $false }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_ai_gather_speed"; TitleLocStringKey = 1962; DescriptionLocStringKey = 1862; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_ai_build_speed"; TitleLocStringKey = 1908; DescriptionLocStringKey = 1908; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_ai_train_speed"; TitleLocStringKey = 1909; DescriptionLocStringKey = 1909; Items = $economyRateItems }
    [pscustomobject]@{ Kind = "Enumeration"; Key = "option_aorpg_ai_max_population"; TitleLocStringKey = 1948; DescriptionLocStringKey = 1948; Items = $populationItems }
)

$warehouse = $script:Document.CreateElement("DataWarehouse")
[void]$script:Document.AppendChild($warehouse)

$winCondition = New-RdoDataObject -Type "WinCondition"
[void]$warehouse.AppendChild($winCondition)

Add-RdoScalarProperty -Owner $winCondition -Name "m_maxTeams" -Type "Int32" -Value "-1" | Out-Null
# Keep Classic Start explicit so the native starting-condition host initializes
# map resources before AoE4RPG applies any optional resource multipliers.
$startingCondition = Add-RdoChildObjectProperty `
    -Owner $winCondition `
    -Name "m_startingCondition" `
    -ChildType "FamilyManagerEnum<FamilyManager::FamilyType::TYP_StartingCondition,StdTraits>"
Add-RdoScalarProperty -Owner $startingCondition -Name "m_enumName" -Type "String" -Value "" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_gameModeType" -Type "String" -Value "" | Out-Null
# RDO resolves the maintained entrypoint from the winconditions directory.
# IMPORTANT: Keep this path exact; it is independent from the tuning GUID field.
Add-RdoScalarProperty -Owner $winCondition -Name "m_scarWinConditionFile" -Type "String" -Value "winconditions\AoE4RPG" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_feAllowSelectingStartingLocations" -Type "Bool" -Value "true" | Out-Null
Add-RdoEmptyObjectProperty -Owner $winCondition -Name "m_playerUpgrades" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_feIcon" -Type "String" -Value "" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_defaultBiomePBGId" -Type "UInt32" -Value "0" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_scarMissionFile" -Type "String" -Value "" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_feImageSelected" -Type "String" -Value "" | Out-Null
Add-RdoLocStringProperty -Owner $winCondition -Name "m_feDescriptionTooltip" -LocStringKey 1857
Add-RdoEmptyObjectProperty -Owner $winCondition -Name "m_startingBuildingReplacements" | Out-Null
Add-RdoLocStringProperty -Owner $winCondition -Name "m_feName" -LocStringKey 1856
# Leave the tuning override empty so the native host resolves the active mod's
# attribute pack and still runs its normal Classic Start initialization.
# IMPORTANT: Do not populate this field with the SCAR/attribute GUID.
Add-RdoScalarProperty -Owner $winCondition -Name "m_tuningModGUID" -Type "String" -Value "" | Out-Null

$optionsDescriptor = Add-RdoChildObjectProperty `
    -Owner $winCondition `
    -Name "m_optionsUIDescriptor" `
    -ChildType "WinCondition::OptionsUIDescriptor"
$sections = Add-RdoObjectCollection `
    -Owner $optionsDescriptor `
    -Name "m_optionSections" `
    -ChildTypes @(
        "WinCondition::OptionSectionUIDescriptor",
        "WinCondition::OptionSectionUIDescriptor",
        "WinCondition::OptionSectionUIDescriptor",
        "WinCondition::OptionSectionUIDescriptor",
        "WinCondition::OptionSectionUIDescriptor"
    )
# Featured sections share the first row with the native Tuning Pack panel.
# Standard sections flow into the following row with the wider dropdown layout.
Add-RdoOptionSection -Section $sections[0] -Key "section_aorpg_victory_conditions" -TitleLocStringKey 1942 -OptionDefinitions $victoryOptions -Featured $true
Add-RdoOptionSection -Section $sections[1] -Key "section_aorpg_leveling" -TitleLocStringKey 1900 -OptionDefinitions $gameplayOptions -Featured $true
Add-RdoOptionSection -Section $sections[2] -Key "section_aorpg_resources" -TitleLocStringKey 1901 -OptionDefinitions $resourceOptions -Featured $true
Add-RdoOptionSection -Section $sections[3] -Key "section_aorpg_player" -TitleLocStringKey 1949 -OptionDefinitions $playerOptions -Featured $false
Add-RdoOptionSection -Section $sections[4] -Key "section_aorpg_ai" -TitleLocStringKey 1946 -OptionDefinitions $aiOptions -Featured $false

$precacheList = Add-RdoChildObjectProperty `
    -Owner $winCondition `
    -Name "m_precacheList" `
    -ChildType "PrecacheList"
$precacheItems = Add-RdoObjectCollection `
    -Owner $precacheList `
    -Name "m_precacheItems" `
    -ChildTypes @("SplatPrecacheItem")
Add-RdoScalarProperty -Owner $precacheItems[0] -Name "#BaseTypes" -Type "String" -Value "IPrecacheItem#0|" | Out-Null
Add-RdoScalarProperty -Owner $precacheItems[0] -Name "m_blueprint" -Type "String" -Value "fx\fx_ring_splat01\fx_ring_splat01" | Out-Null

# Keep the persisted game-mode key aligned with this RDO and its root script.
# A stale key can make the lobby reuse configuration created for another mode.
Add-RdoScalarProperty -Owner $winCondition -Name "m_name" -Type "String" -Value "AoE4RPG" | Out-Null
# AGS leaves this collection empty. Victory objectives are runtime condition
# data; resource PBG loading belongs exclusively to m_precacheList above.
Add-RdoEmptyObjectProperty -Owner $winCondition -Name "m_objectiveUnitTypes" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_devOnly" -Type "Bool" -Value "false" | Out-Null
Add-RdoBareScalarProperty -Owner $winCondition -Name "m_egroupNamePrefixDestroyList" -Type "String" | Out-Null
Add-RdoBareScalarProperty -Owner $winCondition -Name "m_permittedInventoryItemCategories" -Type "String" | Out-Null
Add-RdoScalarProperty -Owner $winCondition -Name "m_feImageUnselected" -Type "String" -Value "" | Out-Null

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    [void](New-Item -ItemType Directory -Path $outputDirectory)
}

$writerSettings = New-Object System.Xml.XmlWriterSettings
$writerSettings.Encoding = New-Object System.Text.UTF8Encoding($false)
$writerSettings.Indent = $true
$writerSettings.IndentChars = "`t"
$writerSettings.NewLineChars = "`r`n"
$writerSettings.NewLineHandling = [System.Xml.NewLineHandling]::Replace
$writerSettings.OmitXmlDeclaration = $true

$writer = [System.Xml.XmlWriter]::Create($OutputPath, $writerSettings)
try {
    $script:Document.Save($writer)
} finally {
    $writer.Dispose()
}

# Fail the generator if routing is accidentally changed or a tuning override
# bypasses the native starting-condition host.
$generatedRdo = [xml](Get-Content -LiteralPath $OutputPath -Raw)
$generatedWinCondition = $generatedRdo.DataWarehouse.DataObject
$generatedScarPath = ($generatedWinCondition.DataProperty |
    Where-Object { $_.Name -eq "m_scarWinConditionFile" }).Value
$generatedTuningGuid = ($generatedWinCondition.DataProperty |
    Where-Object { $_.Name -eq "m_tuningModGUID" }).Value
if ($generatedScarPath -ne "winconditions\AoE4RPG" -or $generatedTuningGuid -ne "") {
    throw "AoE4RPG RDO startup routing must use m_scarWinConditionFile=winconditions\\AoE4RPG and an empty m_tuningModGUID."
}

$locStringRows = @(
    "ID,Pipeline,PipelineStage,Notes,TranslationNotes,Tags,Text",
    "1900,,,,,,Leveling",
    "1901,,,,,,Resources",
    "1902,,,,,,Food",
    "1903,,,,,,Wood",
    "1904,,,,,,Gold",
    "1905,,,,,,Stone",
    "1906,,,,,,Build Speed",
    "1907,,,,,,Train Speed",
    "1908,,,,,,Build Speed",
    "1909,,,,,,Train Speed",
    "1910,,,,,,XP Multiplier",
    "1978,,,,,,Human XP Multiplier",
    "1979,,,,,,AI XP Multiplier",
    "1911,,,,,,1 Class",
    "1912,,,,,,2 Classes",
    "1913,,,,,,3 Classes",
    "1914,,,,,,4 Classes",
    "1915,,,,,,5 Classes",
    "1942,,,,,,Victory Conditions",
    "1943,,,,,,Conquest",
    "1944,,,,,,Annihilation",
    "1945,,,,,,Regicide",
    "1946,,,,,,AI Settings",
    "1947,,,,,,Max Population",
    "1948,,,,,,Max Population",
    "1949,,,,,,Player Settings",
    "1950,,,,,,25",
    "1951,,,,,,50",
    "1952,,,,,,75",
    "1953,,,,,,100",
    "1954,,,,,,150",
    "1955,,,,,,200",
    "1956,,,,,,250",
    "1957,,,,,,300",
    "1958,,,,,,350",
    "1959,,,,,,400",
    "1960,,,,,,Unlimited Levels",
    "1961,,,,,,Maximum Classes",
    "1962,,,,,,Gather Rate",
    "1963,,,,,,15x",
    "1964,,,,,,50x",
    "1965,,,,,,100x",
    "1966,,,,,,1.75x",
    "1967,,,,,,2.5x",
    "1968,,,,,,4x",
    "1969,,,,,,7.5x",
    "1970,,,,,,25x",
    "1971,,,,,,King Level Interval",
    "1972,,,,,,1 Minute",
    "1973,,,,,,2 Minutes",
    "1974,,,,,,3 Minutes",
    "1975,,,,,,5 Minutes",
    "1976,,,,,,10 Minutes",
    "1977,,,,,,15 Minutes",
    "2032,,,,,,Wall Health Multiplier",
    "2033,,,,,,Multiplier applied to the maximum health of stone walls, palisade walls, gates, and palisade defenses.",
    "2034,,,,,,AI Keeps XP on Death",
    "2035,,,,,,AI heroes and elites retain their accumulated RPG experience when they die.",
    "1930,,,,,,0.1x",
    "1931,,,,,,0.25x",
    "1932,,,,,,0.5x",
    "1933,,,,,,0.75x",
    "1934,,,,,,1x",
    "1935,,,,,,1.25x",
    "1936,,,,,,1.5x",
    "1937,,,,,,2x",
    "1938,,,,,,3x",
    "1939,,,,,,5x",
    "1940,,,,,,10x",
    "1941,,,,,,20x"
)
# Essence Editor mod builds expect locstring records in ascending numeric ID
# order. Keep the header fixed and sort every generated data row automatically
# so adding a later locstring cannot silently disturb the build order.
$locStringHeader = $locStringRows[0]
$locStringRows = @($locStringHeader) + @(
    $locStringRows[1..($locStringRows.Count - 1)] | Sort-Object {
        [int](($_ -split ",", 2)[0])
    }
)
$locStringText = ($locStringRows -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText(
    $LocStringOutputPath,
    $locStringText,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Output "Generated: $OutputPath"
Write-Output "Locstrings to merge: $LocStringOutputPath"
