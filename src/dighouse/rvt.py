"""Two relief views from the Relief Visualization Toolbox (RVT), and its VAT blend.

`local_dominance`, `msrm`, `mean_filter` and `integral_image` are copied from rvt-py 2.2.3 (`rvt/vis.py`),
https://github.com/EarthObservation/RVT_py, under the Apache License 2.0, with the docstrings shortened.
Copyright 2010-2020 Research Centre of the Slovenian Academy of Sciences and Arts, and 2016-2020 University of
Ljubljana, Faculty of Civil and Geodetic Engineering. Authors: Žiga Kokalj, Krištof Oštir, Klemen Zakšek, Peter
Pehani, Klemen Čotar, Maja Somrak, Žiga Maroh and Nejc Čož. Local dominance was adapted by RVT from Ralf Hesse's
LiVT. The package itself is not a dependency, because its install metadata stops short of Python 3.12.

`vat` blends four views the way RVT's VAT does (Kokalj and Somrak 2019, Remote Sensing 11(7), 747): hillshade at
the bottom, slope over it by luminosity at 50%, positive openness by overlay at 50%, and sky view by multiply at 25%,
each stretched over the ranges of RVT's VAT for flat ground, since a find's square is mostly gentle. It is written
here from that description.
"""

from __future__ import annotations

import numpy as np


def integral_image(dem: np.ndarray, data_type=np.float64) -> np.ndarray:
    """Summed-area table, origin at the upper left."""
    dem = dem.astype(data_type)
    return dem.cumsum(axis=0).cumsum(axis=1)


def mean_filter(dem: np.ndarray, kernel_radius: int) -> np.ndarray:
    """Mean filter of a square kernel 2 * radius + 1 pixels wide, by shifting an integral image."""
    radius_cell = int(kernel_radius)
    if kernel_radius == 0:
        return dem
    idx_nan_dem = np.isnan(dem)
    dem_pad = np.pad(dem, (radius_cell + 1, radius_cell), mode="edge")
    idx_nan_dem_pad = np.isnan(dem_pad)
    dem_pad[idx_nan_dem_pad] = 0
    dem_i_nr_pixels = np.ones(dem_pad.shape)
    dem_i_nr_pixels[idx_nan_dem_pad] = 0
    dem_i_nr_pixels = integral_image(dem_i_nr_pixels, np.int64)
    dem_i1 = integral_image(dem_pad)
    kernel_nr_pix_arr = (np.roll(dem_i_nr_pixels, (radius_cell, radius_cell), axis=(0, 1)) +
                         np.roll(dem_i_nr_pixels, (-radius_cell - 1, -radius_cell - 1), axis=(0, 1)) -
                         np.roll(dem_i_nr_pixels, (-radius_cell - 1, radius_cell), axis=(0, 1)) -
                         np.roll(dem_i_nr_pixels, (radius_cell, -radius_cell - 1), axis=(0, 1)))
    mean_out = (np.roll(dem_i1, (radius_cell, radius_cell), axis=(0, 1)) +
                np.roll(dem_i1, (-radius_cell - 1, -radius_cell - 1), axis=(0, 1)) -
                np.roll(dem_i1, (-radius_cell - 1, radius_cell), axis=(0, 1)) -
                np.roll(dem_i1, (radius_cell, -radius_cell - 1), axis=(0, 1)))
    with np.errstate(divide="ignore", invalid="ignore"):
        mean_out = mean_out / kernel_nr_pix_arr
    mean_out = mean_out.astype(np.float32)
    mean_out = mean_out[radius_cell:-(radius_cell + 1), radius_cell:-(radius_cell + 1)]
    mean_out[idx_nan_dem] = np.nan
    return mean_out


def msrm(dem: np.ndarray, resolution: float, feature_min: float, feature_max: float, scaling_factor: int) -> np.ndarray:
    """Multi-scale relief model: the mean of the differences between mean-filtered surfaces, for features
    feature_min to feature_max metres across."""
    dem = dem.astype(np.float32)
    feature_min = max(feature_min, resolution)
    scaling_factor = int(scaling_factor)
    i = int(np.floor(((feature_min - resolution) / (2 * resolution)) ** (1 / scaling_factor)))
    n = int(np.ceil(((feature_max - resolution) / (2 * resolution)) ** (1 / scaling_factor)))
    relief_models_sum = np.zeros(dem.shape)
    nr_relief_models = 0
    last_lpf_surface = 0
    for ndx in range(i, n + 1, 1):
        lpf_surface = mean_filter(dem=dem, kernel_radius=ndx ** scaling_factor)
        if not ndx == i:
            relief_models_sum += (last_lpf_surface - lpf_surface)
            nr_relief_models += 1
        last_lpf_surface = lpf_surface
    return relief_models_sum / max(nr_relief_models, 1)


def local_dominance(dem: np.ndarray, min_rad: int = 10, max_rad: int = 20, rad_inc: int = 1, angular_res: int = 15,
                    observer_height: float = 1.7) -> np.ndarray:
    """How far a person standing on each cell sees down onto the ground min_rad to max_rad pixels around."""
    dem = dem.astype(np.float32)
    pad_width = max_rad
    dem = np.pad(array=dem, pad_width=pad_width, mode="edge")
    n_dist = int((max_rad - min_rad) / rad_inc + 1)
    distances = np.arange(n_dist * rad_inc, step=rad_inc) + min_rad
    n_ang = int(359 / angular_res + 1)
    angles = np.arange(n_ang * angular_res, step=angular_res)
    norma = np.sum((observer_height / distances) * (2 * distances + rad_inc)) * n_ang
    n_shifts = distances.size * angles.size
    x_t = (np.outer(np.cos(np.deg2rad(angles)), distances)).reshape(n_shifts)
    y_t = (np.outer(np.sin(np.deg2rad(angles)), distances)).reshape(n_shifts)
    distances = (np.outer(np.ones(n_ang), distances)).reshape(n_shifts)
    dist_factor = 2 * distances + rad_inc
    local_dom_out = dem * 0
    for i_s in range(n_shifts):
        dem_moved = np.roll(dem, int(round(y_t[i_s])), axis=0)
        dem_moved = np.roll(dem_moved, int(round(x_t[i_s])), axis=1)
        idx_lower = np.where((dem + observer_height) > dem_moved)
        if idx_lower[0].size > 0:
            local_dom_out[idx_lower[0], idx_lower[1]] = local_dom_out[idx_lower[0], idx_lower[1]] + \
                (dem[idx_lower[0], idx_lower[1]] + observer_height - dem_moved[idx_lower[0], idx_lower[1]]) / \
                distances[i_s] * dist_factor[i_s]
    local_dom_out = local_dom_out / norma
    return local_dom_out[pad_width:-pad_width, pad_width:-pad_width]


def _range(a: np.ndarray, lo: float, hi: float) -> np.ndarray:
    return np.clip((a - lo) / (hi - lo), 0, 1)


def vat(hillshade: np.ndarray, slope_deg: np.ndarray, openness_pos_deg: np.ndarray, sky_view: np.ndarray) -> np.ndarray:
    """RVT's VAT blend with its flat-ground ranges, 0 to 1. Inputs as Dighouse's terrain module gives them."""
    base = _range(hillshade, 0, 1)
    slope = 1 - _range(slope_deg, 0, 15)                       # steep is dark
    base = 0.5 * slope + 0.5 * base                            # luminosity, 50%
    top = _range(openness_pos_deg, 85, 91)
    over = np.where(base < 0.5, 2 * base * top, 1 - 2 * (1 - base) * (1 - top))
    base = 0.5 * over + 0.5 * base                             # overlay, 50%
    svf = _range(sky_view, 0.9, 1.0)
    return 0.25 * (base * svf) + 0.75 * base                   # multiply, 25%
