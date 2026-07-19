"""
Operation result wrapper for error handling

Provides a Result type similar to Swift's Result<T, Error>.
"""

from typing import Generic, TypeVar, Callable, Union
from dataclasses import dataclass

T = TypeVar('T')
E = TypeVar('E', bound=Exception)


@dataclass
class Success(Generic[T]):
    """Represents a successful operation result"""
    value: T

    def is_success(self) -> bool:
        return True

    def is_failure(self) -> bool:
        return False

    def get_value(self) -> T:
        return self.value

    def get_error(self) -> None:
        return None


@dataclass
class Failure(Generic[E]):
    """Represents a failed operation result"""
    error: E

    def is_success(self) -> bool:
        return False

    def is_failure(self) -> bool:
        return True

    def get_value(self) -> None:
        return None

    def get_error(self) -> E:
        return self.error


# Type alias for convenience
OperationResult = Union[Success[T], Failure[E]]


def result_map(result: OperationResult, func: Callable[[T], T]) -> OperationResult:
    """
    Map a function over a successful result.

    Args:
        result: Operation result
        func: Function to apply to success value

    Returns:
        OperationResult: New result with mapped value, or original failure
    """
    if isinstance(result, Success):
        try:
            return Success(func(result.value))
        except Exception as e:
            return Failure(e)
    return result


def result_flat_map(result: OperationResult, func: Callable[[T], OperationResult]) -> OperationResult:
    """
    Flat map a function over a successful result.

    Args:
        result: Operation result
        func: Function that returns an OperationResult

    Returns:
        OperationResult: Result from func, or original failure
    """
    if isinstance(result, Success):
        try:
            return func(result.value)
        except Exception as e:
            return Failure(e)
    return result
