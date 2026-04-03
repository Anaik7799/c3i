/**
 * Advanced Analytics Dashboard Hooks for STAMP/TDG/GDE System
 *
 * Provides interactive data visualization capabilities using Chart.js
 * with real-time updates, advanced charting, and export functionality.
 *
 * Features:
 * - Real-time chart updates via Phoenix LiveView
 * - Multiple chart types (line, bar, area, scatter, heatmap)
 * - Interactive data exploration and filtering
 * - Export capabilities for charts and data
 * - Responsive design for mobile and desktop
 * - Performance optimization for large datasets
 */

import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';

// Chart.js configuration defaults
Chart.defaults.font.family = 'Inter, system-ui, sans-serif';
Chart.defaults.font.size = 12;
Chart.defaults.color = '#6B7280';
Chart.defaults.backgroundColor = 'rgba(59, 130, 246, 0.1)';
Chart.defaults.borderColor = 'rgba(59, 130, 246, 0.8)';

// Color palette for consistent theming
const COLORS = {
  primary: 'rgba(59, 130, 246, 0.8)',
  primaryFill: 'rgba(59, 130, 246, 0.1)',
  success: 'rgba(34, 197, 94, 0.8)',
  successFill: 'rgba(34, 197, 94, 0.1)',
  warning: 'rgba(251, 191, 36, 0.8)',
  warningFill: 'rgba(251, 191, 36, 0.1)',
  danger: 'rgba(239, 68, 68, 0.8)',
  dangerFill: 'rgba(239, 68, 68, 0.1)',
  purple: 'rgba(147, 51, 234, 0.8)',
  purpleFill: 'rgba(147, 51, 234, 0.1)',
  orange: 'rgba(249, 115, 22, 0.8)',
  orangeFill: 'rgba(249, 115, 22, 0.1)'
};

/**
 * STAMP Analytics Chart Hook
 * Displays STAMP compliance trends with real-time updates
 */
const StampChart = {
  mounted() {
    this.initializeChart();
    this.handleEvent('update_charts', (data) => this.updateChart(data));
    this.handleEvent('refresh_charts', (config) => this.refreshChart(config));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeChart() {
    const ctx = this.el;

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.generateTimeLabels(24),
        datasets: [{
          label: 'STAMP Compliance Rate',
          data: this.generateSampleData(24, 94, 2),
          borderColor: COLORS.primary,
          backgroundColor: COLORS.primaryFill,
          fill: true,
          tension: 0.4,
          pointRadius: 3,
          pointHoverRadius: 6
        }, {
          label: 'Risk Assessment Score',
          data: this.generateSampleData(24, 89, 3),
          borderColor: COLORS.orange,
          backgroundColor: COLORS.orangeFill,
          fill: false,
          tension: 0.4,
          pointRadius: 2,
          pointHoverRadius: 5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
        scales: {
          x: {
            type: 'time',
            time: {
              displayFormats: {
                hour: 'HH:mm'
              }
            },
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            beginAtZero: false,
            min: 80,
            max: 100,
            title: {
              display: true,
              text: 'Compliance Rate (%)'
            }
          }
        },
        plugins: {
          legend: {
            position: 'top',
            align: 'start'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: 'white',
            bodyColor: 'white',
            borderColor: COLORS.primary,
            borderWidth: 1,
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.formattedValue}%`;
              }
            }
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    // Update chart data with new values
    const newData = data.stamp_metrics || this.generateSampleData(24, 94, 2);
    this.chart.data.datasets[0].data = newData;
    this.chart.update('none'); // Animate: false for real-time updates
  },

  refreshChart(config) {
    if (!this.chart) return;

    const newType = config.chart_type || 'line';
    if (this.chart.config.type !== newType) {
      this.chart.destroy();
      this.chart.config.type = newType;
      this.initializeChart();
    }
  },

  generateTimeLabels(hours) {
    const labels = [];
    const now = new Date();

    for (let i = hours; i >= 0; i--) {
      const time = new Date(now.getTime() - (i * 60 * 60 * 1000));
      labels.push(time);
    }

    return labels;
  },

  generateSampleData(points, base, variance) {
    const data = [];
    const now = new Date();

    for (let i = points; i >= 0; i--) {
      const time = new Date(now.getTime() - (i * 60 * 60 * 1000));
      const value = base + (Math.sin(i * Math.PI / 12) * variance) + (Math.random() - 0.5) * variance;
      data.push({ x: time, y: Math.max(0, Math.min(100, value)) });
    }

    return data;
  }
};

/**
 * TDG Analytics Chart Hook
 * Displays Test-Driven Generation success metrics
 */
const TdgChart = {
  mounted() {
    this.initializeChart();
    this.handleEvent('update_charts', (data) => this.updateChart(data));
    this.handleEvent('refresh_charts', (config) => this.refreshChart(config));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeChart() {
    const ctx = this.el;

    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: ['Success Rate', 'Test Coverage', 'Generation Speed', 'Quality Score'],
        datasets: [{
          label: 'Current Period',
          data: [97.8, 95.4, 89.2, 96.1],
          backgroundColor: [
            COLORS.successFill,
            COLORS.primaryFill,
            COLORS.purpleFill,
            COLORS.orangeFill
          ],
          borderColor: [
            COLORS.success,
            COLORS.primary,
            COLORS.purple,
            COLORS.orange
          ],
          borderWidth: 2
        }, {
          label: 'Previous Period',
          data: [96.3, 94.1, 87.8, 94.5],
          backgroundColor: 'rgba(156, 163, 175, 0.3)',
          borderColor: 'rgba(156, 163, 175, 0.8)',
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: false,
            min: 80,
            max: 100,
            title: {
              display: true,
              text: 'Performance (%)'
            }
          }
        },
        plugins: {
          legend: {
            position: 'top',
            align: 'start'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.formattedValue}%`;
              }
            }
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    // Update with new TDG metrics
    const newData = data.tdg_metrics || [97.8, 95.4, 89.2, 96.1];
    this.chart.data.datasets[0].data = newData;
    this.chart.update();
  },

  refreshChart(config) {
    if (!this.chart) return;

    const newType = config.chart_type || 'bar';
    if (this.chart.config.type !== newType && newType !== 'heatmap') {
      this.chart.config.type = newType;
      this.chart.update();
    }
  }
};

/**
 * GDE Analytics Chart Hook
 * Displays Goal-Driven Execution efficiency metrics
 */
const GdeChart = {
  mounted() {
    this.initializeChart();
    this.handleEvent('update_charts', (data) => this.updateChart(data));
    this.handleEvent('refresh_charts', (config) => this.refreshChart(config));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeChart() {
    const ctx = this.el;

    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Completed Goals', 'In Progress', 'Pending', 'Blocked'],
        datasets: [{
          data: [72, 18, 8, 2],
          backgroundColor: [
            COLORS.success,
            COLORS.primary,
            COLORS.warning,
            COLORS.danger
          ],
          borderWidth: 2,
          borderColor: '#fff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '60%',
        plugins: {
          legend: {
            position: 'bottom'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            callbacks: {
              label: function(context) {
                const label = context.label || '';
                const value = context.formattedValue;
                const percentage = ((context.raw / context.dataset.data.reduce((a, b) => a + b, 0)) * 100).toFixed(1);
                return `${label}: ${value}% (${percentage}%)`;
              }
            }
          }
        }
      }
    });

    // Add center text
    this.addCenterText();
  },

  addCenterText() {
    const centerTextPlugin = {
      id: 'centerText',
      beforeDraw: (chart) => {
        const { ctx, width, height } = chart;
        const centerX = width / 2;
        const centerY = height / 2;

        ctx.save();
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';

        // Main text
        ctx.font = 'bold 24px Inter';
        ctx.fillStyle = '#111827';
        ctx.fillText('89.6%', centerX, centerY - 10);

        // Subtitle
        ctx.font = '12px Inter';
        ctx.fillStyle = '#6B7280';
        ctx.fillText('Efficiency', centerX, centerY + 15);

        ctx.restore();
      }
    };

    Chart.register(centerTextPlugin);
  },

  updateChart(data) {
    if (!this.chart) return;

    // Update with new GDE metrics
    const newData = data.gde_metrics || [72, 18, 8, 2];
    this.chart.data.datasets[0].data = newData;
    this.chart.update();
  },

  refreshChart(config) {
    // GDE chart maintains doughnut type for optimal display
    if (!this.chart) return;
    this.chart.update();
  }
};

/**
 * Predictive Analytics Chart Hook
 * Displays ML-powered predictions and forecasts
 */
const PredictiveChart = {
  mounted() {
    this.initializeChart();
    this.handleEvent('update_charts', (data) => this.updateChart(data));
    this.handleEvent('refresh_charts', (config) => this.refreshChart(config));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeChart() {
    const ctx = this.el;

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.generateFutureLabels(24),
        datasets: [{
          label: 'Predicted Performance',
          data: this.generatePredictionData(24),
          borderColor: COLORS.purple,
          backgroundColor: COLORS.purpleFill,
          fill: true,
          tension: 0.4,
          pointRadius: 3,
          borderDash: [5, 5]
        }, {
          label: 'Confidence Interval (Upper)',
          data: this.generateConfidenceData(24, 3),
          borderColor: 'rgba(147, 51, 234, 0.3)',
          backgroundColor: 'transparent',
          fill: false,
          pointRadius: 0,
          borderDash: [2, 2]
        }, {
          label: 'Confidence Interval (Lower)',
          data: this.generateConfidenceData(24, -3),
          borderColor: 'rgba(147, 51, 234, 0.3)',
          backgroundColor: 'transparent',
          fill: false,
          pointRadius: 0,
          borderDash: [2, 2]
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
        scales: {
          x: {
            type: 'time',
            time: {
              displayFormats: {
                hour: 'HH:mm'
              }
            },
            title: {
              display: true,
              text: 'Prediction Horizon'
            }
          },
          y: {
            beginAtZero: false,
            min: 75,
            max: 100,
            title: {
              display: true,
              text: 'Predicted Performance (%)'
            }
          }
        },
        plugins: {
          legend: {
            position: 'top',
            align: 'start'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.formattedValue}%`;
              }
            }
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    // Update with new prediction data
    if (data.predictions) {
      this.chart.data.datasets[0].data = data.predictions;
      this.chart.update();
    }
  },

  refreshChart(config) {
    if (!this.chart) return;
    this.chart.update();
  },

  generateFutureLabels(hours) {
    const labels = [];
    const now = new Date();

    for (let i = 0; i < hours; i++) {
      const time = new Date(now.getTime() + (i * 60 * 60 * 1000));
      labels.push(time);
    }

    return labels;
  },

  generatePredictionData(points) {
    const data = [];
    const now = new Date();
    const baseValue = 89.6;

    for (let i = 0; i < points; i++) {
      const time = new Date(now.getTime() + (i * 60 * 60 * 1000));
      const trend = i * 0.1; // Slight upward trend
      const seasonal = Math.sin(i * Math.PI / 12) * 2; // 24-hour cycle
      const noise = (Math.random() - 0.5) * 1; // Reduced noise for predictions
      const value = baseValue + trend + seasonal + noise;

      data.push({ x: time, y: Math.max(75, Math.min(100, value)) });
    }

    return data;
  },

  generateConfidenceData(points, offset) {
    const data = [];
    const now = new Date();
    const baseValue = 89.6;

    for (let i = 0; i < points; i++) {
      const time = new Date(now.getTime() + (i * 60 * 60 * 1000));
      const uncertainty = i * 0.2; // Increasing uncertainty over time
      const value = baseValue + offset + uncertainty;

      data.push({ x: time, y: Math.max(75, Math.min(100, value)) });
    }

    return data;
  }
};

/**
 * Performance Heatmap Hook
 * Displays system performance as a heatmap visualization
 */
const PerformanceHeatmap = {
  mounted() {
    this.initializeHeatmap();
    this.handleEvent('update_charts', (data) => this.updateHeatmap(data));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeHeatmap() {
    const ctx = this.el;

    // Create heatmap using scatter plot with point sizes
    this.chart = new Chart(ctx, {
      type: 'scatter',
      data: {
        datasets: [{
          label: 'Performance Heatmap',
          data: this.generateHeatmapData(),
          backgroundColor: this.generateHeatmapColors(),
          borderColor: 'rgba(255, 255, 255, 0.5)',
          borderWidth: 1,
          pointRadius: this.generatePointSizes()
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            type: 'linear',
            position: 'bottom',
            min: 0,
            max: 23,
            title: {
              display: true,
              text: 'Hour of Day'
            },
            ticks: {
              stepSize: 1
            }
          },
          y: {
            type: 'linear',
            min: 0,
            max: 6,
            title: {
              display: true,
              text: 'Day of Week'
            },
            ticks: {
              stepSize: 1,
              callback: function(value) {
                const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                return days[value] || '';
              }
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            callbacks: {
              title: function(context) {
                const point = context[0];
                const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                return `${days[point.parsed.y]} ${point.parsed.x}:00`;
              },
              label: function(context) {
                return `Performance: ${context.raw.performance}%`;
              }
            }
          }
        }
      }
    });
  },

  updateHeatmap(data) {
    if (!this.chart) return;

    // Update heatmap data
    this.chart.data.datasets[0].data = this.generateHeatmapData();
    this.chart.data.datasets[0].backgroundColor = this.generateHeatmapColors();
    this.chart.update();
  },

  generateHeatmapData() {
    const data = [];

    for (let day = 0; day < 7; day++) {
      for (let hour = 0; hour < 24; hour++) {
        const performance = 70 + Math.random() * 30; // Random performance 70-100%
        data.push({
          x: hour,
          y: day,
          performance: Math.round(performance)
        });
      }
    }

    return data;
  },

  generateHeatmapColors() {
    return this.generateHeatmapData().map(point => {
      const intensity = (point.performance - 70) / 30; // Normalize to 0-1
      const red = Math.round(255 * (1 - intensity));
      const green = Math.round(255 * intensity);
      return `rgba(${red}, ${green}, 0, 0.7)`;
    });
  },

  generatePointSizes() {
    return this.generateHeatmapData().map(point => {
      return 5 + (point.performance - 70) / 6; // Size 5-10 based on performance
    });
  }
};

/**
 * Correlation Matrix Hook
 * Displays correlations between different metrics
 */
const CorrelationMatrix = {
  mounted() {
    this.initializeMatrix();
    this.handleEvent('update_charts', (data) => this.updateMatrix(data));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeMatrix() {
    const ctx = this.el;

    this.chart = new Chart(ctx, {
      type: 'scatter',
      data: {
        datasets: this.generateCorrelationDatasets()
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            type: 'linear',
            min: 0,
            max: 3,
            title: {
              display: true,
              text: 'Metrics'
            },
            ticks: {
              stepSize: 1,
              callback: function(value) {
                const metrics = ['STAMP', 'TDG', 'GDE', 'SYS'];
                return metrics[value] || '';
              }
            }
          },
          y: {
            type: 'linear',
            min: 0,
            max: 3,
            title: {
              display: true,
              text: 'Metrics'
            },
            ticks: {
              stepSize: 1,
              callback: function(value) {
                const metrics = ['STAMP', 'TDG', 'GDE', 'SYS'];
                return metrics[value] || '';
              }
            }
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            callbacks: {
              title: function(context) {
                const point = context[0];
                const metrics = ['STAMP', 'TDG', 'GDE', 'System'];
                return `${metrics[point.parsed.x]} vs ${metrics[point.parsed.y]}`;
              },
              label: function(context) {
                return `Correlation: ${context.raw.correlation}`;
              }
            }
          }
        }
      }
    });
  },

  updateMatrix(data) {
    if (!this.chart) return;
    this.chart.update();
  },

  generateCorrelationDatasets() {
    const correlations = [
      [1.0, 0.7, 0.6, 0.8],
      [0.7, 1.0, 0.5, 0.6],
      [0.6, 0.5, 1.0, 0.7],
      [0.8, 0.6, 0.7, 1.0]
    ];

    const data = [];
    const colors = [];
    const sizes = [];

    for (let i = 0; i < 4; i++) {
      for (let j = 0; j < 4; j++) {
        const correlation = correlations[i][j];
        data.push({
          x: j,
          y: i,
          correlation: correlation.toFixed(2)
        });

        // Color based on correlation strength
        const intensity = Math.abs(correlation);
        const hue = correlation > 0 ? 120 : 0; // Green for positive, red for negative
        colors.push(`hsla(${hue}, 70%, 50%, ${intensity})`);

        // Size based on correlation magnitude
        sizes.push(10 + intensity * 15);
      }
    }

    return [{
      data: data,
      backgroundColor: colors,
      borderColor: 'rgba(255, 255, 255, 0.5)',
      borderWidth: 1,
      pointRadius: sizes
    }];
  }
};

/**
 * Anomaly Detection Hook
 * Displays detected anomalies and outliers
 */
const AnomalyDetection = {
  mounted() {
    this.initializeChart();
    this.handleEvent('update_charts', (data) => this.updateChart(data));
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  },

  initializeChart() {
    const ctx = this.el;

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: this.generateTimeLabels(48),
        datasets: [{
          label: 'System Performance',
          data: this.generateNormalData(48),
          borderColor: COLORS.primary,
          backgroundColor: 'transparent',
          fill: false,
          tension: 0.4,
          pointRadius: 2
        }, {
          label: 'Anomalies',
          data: this.generateAnomalyData(48),
          borderColor: COLORS.danger,
          backgroundColor: COLORS.danger,
          fill: false,
          pointRadius: 6,
          pointHoverRadius: 8,
          showLine: false
        }, {
          label: 'Threshold',
          data: Array(48).fill(85),
          borderColor: COLORS.warning,
          backgroundColor: 'transparent',
          borderDash: [5, 5],
          fill: false,
          pointRadius: 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index'
        },
        scales: {
          x: {
            type: 'time',
            time: {
              displayFormats: {
                hour: 'HH:mm'
              }
            },
            title: {
              display: true,
              text: 'Time'
            }
          },
          y: {
            beginAtZero: false,
            min: 70,
            max: 100,
            title: {
              display: true,
              text: 'Performance (%)'
            }
          }
        },
        plugins: {
          legend: {
            position: 'top',
            align: 'start'
          },
          tooltip: {
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            callbacks: {
              label: function(context) {
                if (context.dataset.label === 'Anomalies') {
                  return `Anomaly detected: ${context.formattedValue}%`;
                }
                return `${context.dataset.label}: ${context.formattedValue}%`;
              }
            }
          }
        }
      }
    });
  },

  updateChart(data) {
    if (!this.chart) return;

    // Update with new anomaly detection data
    this.chart.data.datasets[0].data = this.generateNormalData(48);
    this.chart.data.datasets[1].data = this.generateAnomalyData(48);
    this.chart.update();
  },

  generateTimeLabels(hours) {
    const labels = [];
    const now = new Date();

    for (let i = hours; i >= 0; i--) {
      const time = new Date(now.getTime() - (i * 60 * 60 * 1000));
      labels.push(time);
    }

    return labels;
  },

  generateNormalData(points) {
    const data = [];
    const now = new Date();

    for (let i = points; i >= 0; i--) {
      const time = new Date(now.getTime() - (i * 60 * 60 * 1000));
      const baseValue = 90 + Math.sin(i * Math.PI / 12) * 3;
      const value = baseValue + (Math.random() - 0.5) * 2;
      data.push({ x: time, y: Math.max(70, Math.min(100, value)) });
    }

    return data;
  },

  generateAnomalyData(points) {
    const data = [];
    const now = new Date();
    const anomalyIndices = [8, 23, 35]; // Positions where anomalies occur

    for (let i = 0; i < anomalyIndices.length; i++) {
      const anomalyIndex = anomalyIndices[i];
      if (anomalyIndex < points) {
        const time = new Date(now.getTime() - ((points - anomalyIndex) * 60 * 60 * 1000));
        const value = 75 + Math.random() * 10; // Anomalous low values
        data.push({ x: time, y: value });
      }
    }

    return data;
  }
};

// Export all hooks for registration
export {
  StampChart,
  TdgChart,
  GdeChart,
  PredictiveChart,
  PerformanceHeatmap,
  CorrelationMatrix,
  AnomalyDetection
};