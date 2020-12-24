#' Create an interactive tech exposure chart in an htmlwidget
#'
#' @param .data a tech exposure data frame
#' @param width width of exported htmlwidget in pixels (single integer value; default == NULL)
#' @param height height of exported htmlwidget in pixels (single integer value; default == NULL)
#' @param ... other options passed on to r2d3::r2d3() (see details)
#'
#' @description
#' The `tech_exposure_chart` function creates an interactive tech exposure chart in an htmlwidget
#'
#' @examples
#'
#' @md
#' @export

tech_exposure_chart <-
  function(.data, width = NULL, height = NULL, ...) {
    .data <- export_data_utf8(.data)

    dependencies <-
      list(
        system.file("techexposure.js", package = "r2dii.interactive"),
        system.file("text_dropdown_jiggle.js", package = "r2dii.interactive")
        )

    r2d3::r2d3(
      data = .data,
      script = system.file("render_tech_exposure.js", package = "r2dii.interactive"),
      dependencies = dependencies,
      css = system.file("2dii_gitbook_style.css", package = "r2dii.interactive"),
      d3_version = 4,
      width = width,
      height = height,
      container = "div",
      ...
    )
  }


as_tech_exposure_data <-
  function(
    investor_name,
    portfolio_name,
    start_year,
    peer_group,
    equity_results_portfolio,
    bonds_results_portfolio,
    indices_equity_results_portfolio,
    indices_bonds_results_portfolio,
    peers_equity_results_portfolio,
    peers_bonds_results_portfolio,
    green_techs = c('RenewablesCap', 'HydroCap', 'NuclearCap', 'Hybrid', 'Electric', "FuelCell", "Hybrid_HDV", "Electric_HDV", "FuelCell_HDV","Ac-Electric Arc Furnace","Dc-Electric Arc Furnace"),
    select_scenario,
    select_scenario_auto,
    select_scenario_shipping,
    select_scenario_other,
    all_tech_levels,
    equity_market_levels,
    dataframe_translations,
    language_select = "EN"
  ) {
    require("dplyr", quietly = TRUE)

    portfolio <-
      list(`Listed Equity` = equity_results_portfolio,
           `Corporate Bonds` = bonds_results_portfolio) %>%
      dplyr::bind_rows(.id = 'asset_class') %>%
      dplyr::filter(investor_name == !!investor_name,
                    portfolio_name == !!portfolio_name) %>%
      dplyr::filter(!is.na(ald_sector))

    asset_classes <-
      portfolio %>%
      dplyr::pull(asset_class) %>%
      unique()

    equity_sectors <-
      portfolio %>%
      dplyr::filter(asset_class == "Listed Equity") %>%
      dplyr::pull(ald_sector) %>%
      unique()

    bonds_sectors <-
      portfolio %>%
      dplyr::filter(asset_class == 'Corporate Bonds') %>%
      dplyr::pull(ald_sector) %>%
      unique()

    indices <-
      list(`Listed Equity` = indices_equity_results_portfolio,
           `Corporate Bonds` = indices_bonds_results_portfolio) %>%
      dplyr::bind_rows(.id = 'asset_class') %>%
      dplyr::filter(asset_class %in% asset_classes) %>%
      dplyr::filter(asset_class == 'Listed Equity' & ald_sector %in% equity_sectors |
                      asset_class == 'Corporate Bonds' & ald_sector %in% bonds_sectors)

    peers <-
      list(`Listed Equity` = peers_equity_results_portfolio,
           `Corporate Bonds` = peers_bonds_results_portfolio) %>%
      dplyr::bind_rows(.id = 'asset_class') %>%
      dplyr::as_tibble() %>%
      dplyr::filter(asset_class %in% asset_classes) %>%
      dplyr::filter(asset_class == 'Listed Equity' & ald_sector %in% equity_sectors |
                      asset_class == 'Corporate Bonds' & ald_sector %in% bonds_sectors) %>%
      dplyr::filter(investor_name == peer_group)

    techexposure_data <-
      dplyr::bind_rows(portfolio, peers, indices) %>%
      dplyr::filter(allocation == 'portfolio_weight') %>%
      dplyr::filter(scenario == dplyr::if_else(ald_sector == "Automotive", select_scenario_auto,
                                               dplyr::if_else(ald_sector == "Shipping", select_scenario_shipping,
                                                              dplyr::if_else(ald_sector %in% c("Cement", "Steel", "Aviation"), select_scenario_other,
                                                 select_scenario)))) %>%
      dplyr::filter(scenario_geography == dplyr::if_else(ald_sector == 'Power', 'GlobalAggregate', 'Global')) %>%
      dplyr::filter(year == start_year) %>%
      dplyr::filter(equity_market == "GlobalMarket") %>%
      dplyr::mutate(green = technology %in% green_techs) %>%
      dplyr::group_by(asset_class, equity_market, portfolio_name, ald_sector) %>%
      dplyr::arrange(asset_class,  portfolio_name,
                     factor(technology, levels = all_tech_levels), dplyr::desc(green)) %>%
      dplyr::mutate(sector_sum = sum(plan_carsten)) %>%
      dplyr::mutate(sector_prcnt = plan_carsten / sum(plan_carsten)) %>%
      dplyr::mutate(sector_cumprcnt = cumsum(sector_prcnt)) %>%
      dplyr::mutate(sector_cumprcnt = dplyr::lag(sector_cumprcnt, default = 0)) %>%
      dplyr::mutate(cumsum = cumsum(plan_carsten)) %>%
      dplyr::mutate(cumsum = dplyr::lag(cumsum, default = 0)) %>%
      dplyr::ungroup() %>%
      dplyr::group_by(asset_class, equity_market, portfolio_name, ald_sector, green) %>%
      dplyr::mutate(green_sum = sum(plan_carsten)) %>%
      dplyr::mutate(green_prcnt = sum(plan_carsten) / sector_sum) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(this_portfolio = portfolio_name == !!portfolio_name) %>%
      dplyr::mutate(equity_market = dplyr::case_when(
        equity_market == 'GlobalMarket' ~ 'Global Market',
        equity_market == 'DevelopedMarket' ~ 'Developed Market',
        equity_market == 'EmergingMarket' ~ 'Emerging Market',
        TRUE ~ equity_market)
      ) %>%
      dplyr::mutate(portfolio_name = dplyr::case_when(
        portfolio_name == 'pensionfund' ~ 'Pension Fund',
        portfolio_name == 'assetmanager' ~ 'Asset Manager',
        portfolio_name == 'bank' ~ 'Bank',
        portfolio_name == 'insurance' ~ 'Insurance',
        TRUE ~ portfolio_name)
      ) %>%
      dplyr::arrange(asset_class, factor(equity_market, levels = equity_market_levels), dplyr::desc(this_portfolio), portfolio_name,
              factor(technology, levels = all_tech_levels), dplyr::desc(green)) %>%
      dplyr::select(asset_class, equity_market, portfolio_name, this_portfolio, ald_sector, technology,
             plan_carsten, sector_sum, sector_prcnt, cumsum, sector_cumprcnt,
             green, green_sum, green_prcnt)

    dictionary <- choose_dictionary_language(
      dataframe_translations,
      language = language_select
    )

    techexposure_data <- translate_df_contents(techexposure_data, dictionary)

    return(techexposure_data)
  }