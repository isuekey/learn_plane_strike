from flax import linen as nn
from flax import optim
import jax
import jax.numpy as jnp
from jax import random
from jax.experimental import jax2tf
import random as nprandom
import tensorflow as tf
import functools
import numpy as np
from flax.metrics import tensorboard

BOARD_SIZE = 8
PLANE_SIZE = 8
ITERATIONS = 500_000
#ITERATIONS = 500
LR = 1E-2
WINDOW_SIZE = 50
LOGDIR = "./log/"

import tensorflow as tf
from jax.experimental import jax2tf
from flax.metrics import tensorboard
from flax import linen as nn
import jax.numpy as jnp
from jax import random
import numpy as np
from flax import optim
import jax
import random as nprandom
import functools

def compute_loss(logits, labels, rewards):
  one_hot_labels = jax.nn.one_hot(labels, num_classes=BOARD_SIZE**2)
  loss = -jnp.mean(jnp.sum(one_hot_labels * jnp.log(logits), axis=-1) * jnp.asarray(rewards))
  return loss

def init_game():
  hidden_board = np.zeros((BOARD_SIZE, BOARD_SIZE))
  plane_orientation = nprandom.randint(0, 3)
  if plane_orientation == 0:
    plane_core_row = nprandom.randint(1, BOARD_SIZE - 2)
    plane_core_column = nprandom.randint(2, BOARD_SIZE - 2)
    # Populate the tail
    hidden_board[plane_core_row][plane_core_column - 2] = 1
    hidden_board[plane_core_row - 1][plane_core_column - 2] = 1
    hidden_board[plane_core_row + 1][plane_core_column - 2] = 1
  elif plane_orientation == 1:
    plane_core_row = nprandom.randint(1, BOARD_SIZE - 3)
    plane_core_column = nprandom.randint(1, BOARD_SIZE - 3)
    # Populate the tail
    hidden_board[plane_core_row + 2][plane_core_column] = 1
    hidden_board[plane_core_row + 2][plane_core_column + 1] = 1
    hidden_board[plane_core_row + 2][plane_core_column - 1] = 1
  elif plane_orientation == 2:
    plane_core_row = nprandom.randint(1, BOARD_SIZE - 2)
    plane_core_column = nprandom.randint(1, BOARD_SIZE - 3)
    # Populate the tail
    hidden_board[plane_core_row][plane_core_column + 2] = 1
    hidden_board[plane_core_row - 1][plane_core_column + 2] = 1
    hidden_board[plane_core_row + 1][plane_core_column + 2] = 1
  elif plane_orientation == 3:
    plane_core_row = nprandom.randint(2, BOARD_SIZE - 2)
    plane_core_column = nprandom.randint(1, BOARD_SIZE - 2)
    # Populate the tail
    hidden_board[plane_core_row - 2][plane_core_column] = 1
    hidden_board[plane_core_row - 2][plane_core_column + 1] = 1
    hidden_board[plane_core_row - 2][plane_core_column - 1] = 1
  # Populate the cross
  hidden_board[plane_core_row][plane_core_column] = 1
  hidden_board[plane_core_row + 1][plane_core_column] = 1
  hidden_board[plane_core_row - 1][plane_core_column] = 1
  hidden_board[plane_core_row][plane_core_column + 1] = 1
  hidden_board[plane_core_row][plane_core_column - 1] = 1
  return hidden_board

@jax.jit
def run_inference(params, board):
  logits = PolicyGradient().apply({'params':params}, board)
  return logits

@jax.jit
def train_iteration(optimizer, board_pos_log, action_log, reward_log):
  def loss_fn(params):
    logits = PolicyGradient().apply({'params':params}, board_pos_log)
    loss = compute_loss(logits, action_log, reward_log)
    return loss
  grad_fn = jax.grad(loss_fn)
  grads = grad_fn(optimizer.target)
  optimizer = optimizer.apply_gradient(grads)
  return optimizer

compactWeight = [0.5 ** i for i in range(64)]
extractWeight = [2 ** i for i in range(64)]

def arrayReducer(array, item):
  pre = array[-1]
  sumval = pre + item
  array.append(sumval)
  return array
#Reward shaping
def rewards_calculator(hit_logs, gama=0.5):
  hit_range = range(len(hit_logs))
  hits = 0;
  #hit_sum1 = [sum(hit_logs[:i]) for i in hit_range]
  hit_sum = functools.reduce(arrayReducer, hit_logs, [0.])[:-1]
  #print('hitsum is ok', hit_sum1 == hit_sum, hit_sum1, hit_sum)
  hit_log_weighted = [(item - float(PLANE_SIZE - hit_sum[index]) / float(BOARD_SIZE**2 - index)) * (compactWeight[index]) for index, item in enumerate(hit_logs)]
  reversedWeighted = hit_log_weighted.copy()
  reversedWeighted.reverse()
  # weight_sum1 = [sum(hit_log_weighted[idx:]) for idx in hit_range]
  weight_sum = functools.reduce(arrayReducer, reversedWeighted, [0.])[1:]
  weight_sum.reverse()
  # print('weight sum is ok', weight_sum1 == weight_sum, weight_sum1, weight_sum)
  return [(extractWeight[i]) * weight_sum[i] for i in range(len(hit_logs))]
  #hit_log_weighted = [(item - float(PLANE_SIZE - sum(hit_logs[:index])) / float(BOARD_SIZE**2 - index)) * (gama ** index) for index, item in enumerate(hit_logs)]
  #return [(gama ** (-i)) * sum(hit_log_weighted[i:]) for i in range(len(hit_logs))]

def play_game(optimizer, training):
  hidden_board = init_game()
  game_board = np.zeros((BOARD_SIZE, BOARD_SIZE))
  board_pos_log = []
  action_log = []
  hit_log = []
  hits = 0
  while (hits < PLANE_SIZE and len(action_log) < BOARD_SIZE**2):
    board_pos_log.append(np.copy(game_board))
    probs = run_inference(optimizer.target, np.expand_dims(game_board, 0))[0]
    # actionSet = set(action_log)
    # probs = [p * (index not in actionSet) for index, p in enumerate(probs)]
    probs = [p * (index not in action_log) for index, p in enumerate(probs)]
    psum = sum(probs)
    probs = [p / psum for p in probs]
    if training:
      strike_pos = np.random.choice(BOARD_SIZE**2, p=probs)
    else:
      strike_pos = np.argmax(probs)
    x = strike_pos // BOARD_SIZE
    y = strike_pos % BOARD_SIZE
    if hidden_board[x][y] == 1:
      hits = hits + 1
      game_board[x][y] = 1
      hit_log.append(1)
    else:
      game_board[x][y] = -1
      hit_log.append(0)
    action_log.append(strike_pos)
    if training == False:
      print(str(x) + ', ' + str(y) + ' *** ' + str(hit_log[-1]))
      return
  return np.asarray(board_pos_log), np.asarray(action_log), np.asarray(hit_log)

def create_optimizer(params, learning_rate: float):
  optimizer_def = optim.GradientDescent(learning_rate)
  optimizer = optimizer_def.create(params)
  return optimizer

def train(summary_writer):
  batch_metrics = []
  game_lengths = []
  rng = random.PRNGKey(0)
  rng, init_rng = random.split(rng)
  policygradient = PolicyGradient()
  params = policygradient.init(init_rng, jnp.ones([1, BOARD_SIZE, BOARD_SIZE]))['params']
  optimizer = create_optimizer(params=params, learning_rate=LR)
  board_pos = np.zeros((BOARD_SIZE, BOARD_SIZE))
  for i in range(ITERATIONS):
    board_pos_log, action_log, hit_log = play_game(optimizer, True)
    game_lengths.append(len(action_log))
    reward_log = rewards_calculator(hit_log)
    summary_writer.scalar('game_length', len(board_pos_log), i)
    optimizer = train_iteration(optimizer, board_pos_log, action_log, reward_log)
  return optimizer.target, game_lengths

class PolicyGradient(nn.Module):  
  @nn.compact
  def __call__(self, x):
    dtype = jnp.float32
    x = x.reshape((x.shape[0], -1))
    x = nn.Dense(features=2*BOARD_SIZE**2, name='hidden1', dtype=dtype)(x)
    x = nn.relu(x)
    x = nn.Dense(features=BOARD_SIZE**2, name='hidden2', dtype=dtype)(x)
    x = nn.relu(x)
    x = nn.Dense(features=BOARD_SIZE**2, name='logits', dtype=dtype)(x)
    policy_probabilities = nn.softmax(x)
    return policy_probabilities

model = PolicyGradient()
summary_writer = tensorboard.SummaryWriter(LOGDIR)
params, game_lengths = train(summary_writer)
predict_fn = lambda input: model.apply({"params":params}, input)

tf_predict = tf.function(
  jax2tf.convert(predict_fn, enable_xla=False),
  input_signature=[
    tf.TensorSpec(shape=[1, BOARD_SIZE, BOARD_SIZE], dtype=tf.float32, name='input')
  ],
  autograph=False)

converter = tf.lite.TFLiteConverter.from_concrete_functions(
  [tf_predict.get_concrete_function()]
)

with open('plane_strike.tflite', 'wb') as f:
  f.write(tflite_model)

# 做了些优化但是感觉影响不大，快不了多少。
# 因为核心计算过程没有啥好优化的，
# 如果没有策略上的变化，优化效果不大
      
